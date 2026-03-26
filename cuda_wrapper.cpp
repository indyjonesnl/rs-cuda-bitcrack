/*
 * CUDA Wrapper Implementation
 * Bridges Rust FFI to CUDA secp256k1 implementation
 */

#include "cuda_wrapper.h"
#include "SECP256k1.h"
#include "Int.h"
#include "Point.h"
#include "Base58.h"
#include "GPU/SearchKernel.h"
#include <cstring>
#include <cstdio>
#include <vector>

#ifdef __NVCC__
#include <cuda_runtime.h>
#else
// Minimal CUDA runtime stubs for when CUDA is not available
#define cudaSuccess 0
typedef int cudaError_t;
inline const char* cudaGetErrorString(cudaError_t) { return "CUDA not available"; }
inline cudaError_t cudaSetDevice(int) { return 0; }
inline cudaError_t cudaDeviceReset() { return 0; }
struct cudaDeviceProp {
    char name[256];
    int major, minor;
    size_t totalGlobalMem;
    int multiProcessorCount;
};
inline cudaError_t cudaGetDeviceProperties(cudaDeviceProp*, int) { return 1; }
#endif

static Secp256K1* secp = nullptr;

// Helper function to decode Bitcoin address to hash160
static bool decode_address_to_hash160(const char* address, uint8_t* hash160_out) {
    std::vector<uint8_t> decoded;
    if (!DecodeBase58(address, decoded)) {
        fprintf(stderr, "Failed to decode Base58 address\n");
        return false;
    }

    // Bitcoin address format: [1 byte version][20 bytes hash160][4 bytes checksum]
    if (decoded.size() != 25) {
        fprintf(stderr, "Invalid decoded address size: %zu (expected 25)\n", decoded.size());
        return false;
    }

    // Extract hash160 (skip version byte, before checksum)
    memcpy(hash160_out, &decoded[1], 20);
    return true;
}

extern "C" {

bool gpu_init(int device_id) {
    try {
        // Initialize CUDA device
        cudaError_t err = cudaSetDevice(device_id);
        if (err != cudaSuccess) {
            // Silently fail - Rust code will handle fallback to CPU
            // Only print error on first failure to avoid spamming logs
            static bool error_printed = false;
            if (!error_printed) {
                fprintf(stderr, "Note: GPU not available (%s), falling back to CPU\n", cudaGetErrorString(err));
                error_printed = true;
            }
            return false;
        }

        // Initialize secp256k1 context
        if (!secp) {
            secp = new Secp256K1();
            secp->Init();
        }

        return true;
    } catch (const std::exception& e) {
        fprintf(stderr, "GPU init exception: %s\n", e.what());
        return false;
    }
}

void gpu_cleanup() {
    if (secp) {
        delete secp;
        secp = nullptr;
    }
    cudaDeviceReset();
}

bool gpu_generate_address(
    const uint8_t* private_key,
    char* address_out,
    int address_type
) {
    if (!secp) {
        fprintf(stderr, "GPU not initialized\n");
        return false;
    }

    try {
        // Create Int from private key bytes
        Int privKey;
        privKey.SetInt32(0);
        for (int i = 0; i < 32; i++) {
            privKey.ShiftL(8);
            privKey.Add((uint64_t)private_key[i]);
        }

        // Compute public key: Q = privKey * G
        Point publicKey = secp->ComputePublicKey(&privKey);

        // Generate address (P2PKH only)
        std::string addr = secp->GetAddress(0, true, publicKey);

        // Copy address to output buffer
        strncpy(address_out, addr.c_str(), 34);
        address_out[34] = '\0';

        return true;
    } catch (const std::exception& e) {
        fprintf(stderr, "Address generation exception: %s\n", e.what());
        return false;
    }
}

bool gpu_search_address(
    const char* target_address,
    const uint8_t* range_min,
    const uint8_t* range_max,
    uint8_t* private_key_out
) {
    if (!secp) {
        fprintf(stderr, "GPU not initialized\n");
        return false;
    }

    try {
        // Decode target address to get hash160
        uint8_t target_hash160[20];
        if (!decode_address_to_hash160(target_address, target_hash160)) {
            fprintf(stderr, "Failed to decode target address\n");
            return false;
        }


        // Convert range bounds to Int
        Int keyMin, keyMax;
        keyMin.SetInt32(0);
        keyMax.SetInt32(0);

        for (int i = 0; i < 32; i++) {
            keyMin.ShiftL(8);
            keyMin.Add((uint64_t)range_min[i]);
            keyMax.ShiftL(8);
            keyMax.Add((uint64_t)range_max[i]);
        }

        // ===== STRIDE-OPTIMIZED GPU SEARCH =====
        // Each GPU thread generates 1024 keys using batch modular inverse
        // This eliminates the CPU bottleneck - 100-1000x speedup!

        const uint32_t KEYS_PER_THREAD = 1024;  // STEP_SIZE from GPUEngine.h
        const uint32_t MAX_FOUND = 256;         // Max results to store
        const int THREADS_PER_BLOCK = 256;

        // Calculate number of thread blocks needed
        // Each block of threads processes KEYS_PER_THREAD keys (all threads in block work on same range)
        Int rangeSize = keyMax;
        rangeSize.Sub(&keyMin);
        rangeSize.Add(1);

        // Divide range by KEYS_PER_THREAD to get number of blocks
        Int blocksNeeded = rangeSize;
        Int stride;
        stride.SetInt32(KEYS_PER_THREAD);
        blocksNeeded.Div(&stride);
        blocksNeeded.Add(1);  // Round up

        // For very large ranges, process in batches to avoid CPU bottleneck
        const uint32_t MAX_BLOCKS_PER_BATCH = 65536;  // 64K blocks = 67M keys per batch
        uint32_t totalBlocks = blocksNeeded.GetInt32();
        uint32_t numBatches = (totalBlocks + MAX_BLOCKS_PER_BATCH - 1) / MAX_BLOCKS_PER_BATCH;

        printf("Searching with GPU stride optimization (%u blocks in %u batches)...\n", totalBlocks, numBatches);

        // Allocate GPU memory (sized for one batch)
        uint64_t *d_startPoints;      // Starting points (x,y) for each block
        uint32_t *d_target_h160;      // Target hash160 (5 uint32_t)
        uint32_t *d_results;          // Results buffer

        cudaMalloc(&d_startPoints, MAX_BLOCKS_PER_BATCH * THREADS_PER_BLOCK * 8 * sizeof(uint64_t));
        cudaMalloc(&d_target_h160, 5 * sizeof(uint32_t));
        cudaMalloc(&d_results, (MAX_FOUND * 7 + 1) * sizeof(uint32_t));

        // Prepare target hash160 (convert from uint8_t[20] to uint32_t[5])
        // IMPORTANT: The GPU kernel expects the hash160 in the correct byte order
        uint32_t target_h160_u32[5];
        memcpy(target_h160_u32, target_hash160, 20);

        cudaMemcpy(d_target_h160, target_h160_u32, 5 * sizeof(uint32_t), cudaMemcpyHostToDevice);

        // Allocate host buffer for one batch
        uint64_t *h_startPoints = new uint64_t[MAX_BLOCKS_PER_BATCH * THREADS_PER_BLOCK * 8];
        uint32_t *h_results = new uint32_t[MAX_FOUND * 7 + 1];

        // The kernel searches range [center - 512, center + 511]
        // For each batch, we need to position the center correctly
        // The first batch should search from keyMin, so center = keyMin + 512
        Int currentKey = keyMin;
        Int halfStride;
        halfStride.SetInt32(KEYS_PER_THREAD / 2);  // 512
        currentKey.Add(&halfStride);

        // Precompute stride point for fast iteration: stridePoint = 1024*G
        Point stridePoint = secp->ComputePublicKey(&stride);

        // Compute the very first starting point ONCE (expensive EC multiplication)
        // All subsequent points use fast EC addition
        Point currentPoint = secp->ComputePublicKey(&currentKey);

        // Process range in batches
        bool found = false;
        uint32_t processedBlocks = 0;

        for (uint32_t batchIdx = 0; batchIdx < numBatches && !found; batchIdx++) {
            uint32_t blocksInBatch = (processedBlocks + MAX_BLOCKS_PER_BATCH <= totalBlocks)
                                      ? MAX_BLOCKS_PER_BATCH
                                      : (totalBlocks - processedBlocks);

            if (numBatches > 1 && batchIdx % 10 == 0) {
                printf("  Progress: batch %u/%u (%.1f%%)...\n",
                       batchIdx + 1, numBatches,
                       100.0 * processedBlocks / totalBlocks);
            }

            // Compute starting points for this batch using EC addition
            memset(h_startPoints, 0, blocksInBatch * THREADS_PER_BLOCK * 8 * sizeof(uint64_t));

            // Use the current point (already computed or carried over from previous batch)
            Point batchPoint = currentPoint;

            for (uint32_t i = 0; i < blocksInBatch; i++) {
                // Memory layout for Load256A: structure of arrays (SoA)
                // Each thread in the block reads the SAME value (all threads share starting point)
                // Layout: x[0..blockDim-1], x[blockDim..2*blockDim-1], x[2*blockDim..3*blockDim-1], x[3*blockDim..4*blockDim-1]
                //         y[4*blockDim..5*blockDim-1], y[5*blockDim..6*blockDim-1], y[6*blockDim..7*blockDim-1], y[7*blockDim..8*blockDim-1]
                uint32_t baseIdx = i * THREADS_PER_BLOCK * 8;

                // Broadcast x coordinate to all threads in block
                for (uint32_t t = 0; t < THREADS_PER_BLOCK; t++) {
                    h_startPoints[baseIdx + t + 0*THREADS_PER_BLOCK] = batchPoint.x.bits64[0];
                    h_startPoints[baseIdx + t + 1*THREADS_PER_BLOCK] = batchPoint.x.bits64[1];
                    h_startPoints[baseIdx + t + 2*THREADS_PER_BLOCK] = batchPoint.x.bits64[2];
                    h_startPoints[baseIdx + t + 3*THREADS_PER_BLOCK] = batchPoint.x.bits64[3];
                }

                // Broadcast y coordinate to all threads in block
                for (uint32_t t = 0; t < THREADS_PER_BLOCK; t++) {
                    h_startPoints[baseIdx + t + 4*THREADS_PER_BLOCK] = batchPoint.y.bits64[0];
                    h_startPoints[baseIdx + t + 5*THREADS_PER_BLOCK] = batchPoint.y.bits64[1];
                    h_startPoints[baseIdx + t + 6*THREADS_PER_BLOCK] = batchPoint.y.bits64[2];
                    h_startPoints[baseIdx + t + 7*THREADS_PER_BLOCK] = batchPoint.y.bits64[3];
                }

                // Move to next starting point using EC addition (MUCH faster than multiplication!)
                batchPoint = secp->AddDirect(batchPoint, stridePoint);
                currentKey.Add(&stride);
            }

            // Update currentPoint for next batch (carry over the last computed point)
            currentPoint = batchPoint;

            // Copy to GPU and launch kernel
            cudaMemcpy(d_startPoints, h_startPoints, blocksInBatch * THREADS_PER_BLOCK * 8 * sizeof(uint64_t), cudaMemcpyHostToDevice);

            // Clear results buffer
            cudaMemset(d_results, 0, sizeof(uint32_t));

            bool success = launch_stride_search(
                d_startPoints,
                d_target_h160,
                blocksInBatch * THREADS_PER_BLOCK,  // Total number of threads in this batch
                MAX_FOUND,
                d_results,
                THREADS_PER_BLOCK
            );

            // Debug: Check for any CUDA errors after kernel
            cudaError_t err = cudaGetLastError();
            if (err != cudaSuccess) {
                fprintf(stderr, "CUDA error after kernel: %s\n", cudaGetErrorString(err));
            }

            if (!success) {
                fprintf(stderr, "GPU stride kernel failed on batch %u\n", batchIdx);
                delete[] h_startPoints;
                delete[] h_results;
                cudaFree(d_startPoints);
                cudaFree(d_target_h160);
                cudaFree(d_results);
                return false;
            }

            // Check results
            cudaMemcpy(h_results, d_results, (MAX_FOUND * 7 + 1) * sizeof(uint32_t), cudaMemcpyDeviceToHost);

            uint32_t numFound = h_results[0];

            if (numFound > 0) {
                // Parse first result
                uint32_t threadId = h_results[1];                    // Thread ID within this batch
                uint32_t info = h_results[2];                        // (incr << 16) | (mode << 15) | endo
                int16_t incr_s16 = (int16_t)(info >> 16);            // Sign-extend from 16 bits
                int32_t incr = incr_s16;                             // Now a proper signed 32-bit value

                // Calculate which block found the key (within this batch)
                uint32_t blockId = threadId / THREADS_PER_BLOCK;

                // Calculate the actual private key
                // The kernel searches from a center point at keyMin + 512 + blockId*1024
                // The stored incr is the index passed to CHECK_EXACT_HASH160, which ranges 0-1023
                // Index mapping:
                // - Index 0: center - 512
                // - Index 511: center - 1
                // - Index 512: center
                // - Index 513: center + 1
                // - Index 1023: center + 511
                // So the offset from center = incr - 512
                // And actualKey = (keyMin + 512) + blockId*1024 + (incr - 512)
                //              = keyMin + blockId*1024 + incr

                Int foundKey = keyMin;

                // Add the block offset (which block found it)
                Int totalBlockOffset;
                totalBlockOffset.SetInt32((processedBlocks + blockId) * KEYS_PER_THREAD);
                foundKey.Add(&totalBlockOffset);

                // Add the index directly (it already includes the offset from block start)
                // NOTE: The sign of incr from the kernel indicates y-parity for hash160,
                // but we take absolute value since private key is the same
                uint32_t absIncr = (uint32_t)(incr < 0 ? -incr : incr);
                Int incrOffset;
                incrOffset.SetInt32(absIncr);
                foundKey.Add(&incrOffset);

                // Verify the found key is within the valid range
                // This is necessary because the kernel searches 1024 keys even if the range is smaller
                if (foundKey.IsGreaterOrEqual(&keyMin) && foundKey.IsLowerOrEqual(&keyMax)) {
                    printf("Found! Key: %s (batch %u/%u)\n", foundKey.GetBase16().c_str(), batchIdx + 1, numBatches);
                    uint8_t temp[32];
                    foundKey.Get32Bytes(temp);
                    memcpy(private_key_out, temp, 32);
                    found = true;
                } else {
                    // Found a match but it's outside the valid range
                    // This can happen for small ranges
                    // where the kernel searches 1024 keys starting from keyMin+512
                    printf("Debug: Found match at key %s but it's outside range [%s, %s]\n",
                           foundKey.GetBase16().c_str(), keyMin.GetBase16().c_str(), keyMax.GetBase16().c_str());
                }
            }

            processedBlocks += blocksInBatch;
        }

        // Cleanup
        delete[] h_startPoints;
        delete[] h_results;
        cudaFree(d_startPoints);
        cudaFree(d_target_h160);
        cudaFree(d_results);

        if (!found) {
            printf("Search complete. Target not found in range.\n");
        }

        return found;

    } catch (const std::exception& e) {
        fprintf(stderr, "Search exception: %s\n", e.what());
        return false;
    }
}

bool gpu_get_device_info(int device_id, GpuDeviceInfo* info) {
    cudaDeviceProp prop;
    cudaError_t err = cudaGetDeviceProperties(&prop, device_id);

    if (err != cudaSuccess) {
        return false;
    }

    strncpy(info->name, prop.name, 255);
    info->name[255] = '\0';
    info->compute_capability_major = prop.major;
    info->compute_capability_minor = prop.minor;
    info->total_memory = prop.totalGlobalMem;
    info->multiprocessor_count = prop.multiProcessorCount;

    return true;
}

} // extern "C"
