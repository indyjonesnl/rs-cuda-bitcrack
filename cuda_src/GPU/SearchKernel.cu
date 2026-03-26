/*
 * GPU-Accelerated CUDA Kernel for Bitcoin Puzzle Sequential Key Search
 * GPU computes hash160 and compares - keys still precomputed on CPU
 */

#include "SearchKernel.h"
#include "GPUGroup.h"
#include "GPUMath.h"
#include "GPUHash.h"
#include "GPUCompute.h"
#include <cuda_runtime.h>
#include <stdint.h>
#include <stdio.h>

// Kernel for exact hash160 matching (Bitcoin puzzle solver)
// Wraps ComputeKeysExact from GPUCompute.h
__global__ void comp_keys_exact(const uint32_t *target_h160, uint64_t *keys, uint32_t maxFound, uint32_t *found) {
  int xPtr = (blockIdx.x*blockDim.x) * 8;
  int yPtr = xPtr + 4 * blockDim.x;
  ComputeKeysExact(keys + xPtr, keys + yPtr, target_h160, maxFound, found);
}

/**
 * GPU kernel: Check hash160 for batch of precomputed public keys
 * Simple version - full GPU key generation requires precomputed stride tables
 *
 * @param pubkeys_x Public key X coordinates array
 * @param pubkeys_y Public key Y coordinates array
 * @param num_keys Number of keys to check
 * @param targetHash160 Target address hash160 (20 bytes)
 * @param found_key_offset Output: offset where key was found (-1 if not found)
 */
__global__ void search_kernel_incremental(
    const uint64_t *pubkeys_x,
    const uint64_t *pubkeys_y,
    const uint32_t num_keys,
    const uint8_t *targetHash160,
    int32_t *found_key_offset
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx >= num_keys) {
        return;
    }

    // Load this thread's public key
    uint64_t px[4], py[4];
    px[0] = pubkeys_x[idx * 4 + 0];
    px[1] = pubkeys_x[idx * 4 + 1];
    px[2] = pubkeys_x[idx * 4 + 2];
    px[3] = pubkeys_x[idx * 4 + 3];

    py[0] = pubkeys_y[idx * 4 + 0];
    py[1] = pubkeys_y[idx * 4 + 1];
    py[2] = pubkeys_y[idx * 4 + 2];
    py[3] = pubkeys_y[idx * 4 + 3];

    // Compute hash160 for compressed public key
    uint32_t hash[5];
    uint8_t isOdd = (uint8_t)(py[0] & 1);
    _GetHash160Comp(px, isOdd, (uint8_t*)hash);

    // Load target hash160
    const uint32_t *target = (const uint32_t*)targetHash160;

    // Compare with target
    if (hash[0] == target[0] &&
        hash[1] == target[1] &&
        hash[2] == target[2] &&
        hash[3] == target[3] &&
        hash[4] == target[4]) {

        // Found! Write the offset
        *found_key_offset = idx;
    }
}

/**
 * Host function to launch the incremental search kernel
 */
extern "C" bool launch_incremental_search(
    const uint64_t *d_startPoint_x,
    const uint64_t *d_startPoint_y,
    uint32_t num_keys,
    const uint8_t *d_targetHash160,
    int32_t *d_found_key_offset,
    int gridSize,
    int blockSize
) {
    // Launch kernel
    search_kernel_incremental<<<gridSize, blockSize>>>(
        d_startPoint_x,
        d_startPoint_y,
        num_keys,
        d_targetHash160,
        d_found_key_offset
    );

    // Check for launch errors
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA kernel launch error: %s\n", cudaGetErrorString(err));
        return false;
    }

    // Wait for kernel to complete
    cudaDeviceSynchronize();

    // Check for execution errors
    err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA kernel execution error: %s\n", cudaGetErrorString(err));
        return false;
    }

    return true;
}

/**
 * Host function to launch the stride-optimized search kernel
 * Uses VanitySearch's ComputeKeysExact for batch modular inverse optimization
 */
extern "C" bool launch_stride_search(
    uint64_t *d_startPoints,
    const uint32_t *d_targetHash160,
    uint32_t num_threads,
    uint32_t maxFound,
    uint32_t *d_found_results,
    int threadsPerBlock
) {
    // Calculate grid dimensions
    int numBlocks = (num_threads + threadsPerBlock - 1) / threadsPerBlock;

    // Launch the stride-optimized kernel
    comp_keys_exact<<<numBlocks, threadsPerBlock>>>(
        d_targetHash160,
        d_startPoints,
        maxFound,
        d_found_results
    );

    // Check for launch errors
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA stride kernel launch error: %s\n", cudaGetErrorString(err));
        return false;
    }

    // Wait for kernel to complete
    cudaDeviceSynchronize();

    // Check for execution errors
    err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA stride kernel execution error: %s\n", cudaGetErrorString(err));
        return false;
    }

    return true;
}
