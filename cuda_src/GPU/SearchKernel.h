/*
 * Header for simplified Bitcoin address search kernel
 */

#ifndef SEARCH_KERNEL_H
#define SEARCH_KERNEL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Launch the GPU search kernel with incremental key generation
 *
 * @param startPoint_x Device pointer to starting public key X coordinate (4 uint64_t)
 * @param startPoint_y Device pointer to starting public key Y coordinate (4 uint64_t)
 * @param num_keys Number of keys to check
 * @param targetHash160 Device pointer to target hash160 (20 bytes)
 * @param found_key_offset Device pointer to output offset (-1 if not found)
 * @param gridSize Number of thread blocks
 * @param blockSize Threads per block
 * @return true if kernel launched successfully
 */
bool launch_incremental_search(
    const uint64_t *d_startPoint_x,
    const uint64_t *d_startPoint_y,
    uint32_t num_keys,
    const uint8_t *d_targetHash160,
    int32_t *d_found_key_offset,
    int gridSize,
    int blockSize
);

/**
 * Launch stride-optimized GPU search kernel
 * Uses VanitySearch's batch modular inverse optimization for 100-1000x speedup
 * Each thread generates 1024 keys using precomputed stride tables
 *
 * @param startPoints Device pointer to starting public key points (x,y as uint64_t[4] each, per thread)
 * @param targetHash160 Device pointer to target hash160 (5 uint32_t)
 * @param num_threads Number of GPU threads to launch
 * @param maxFound Maximum number of results to store
 * @param found_results Device pointer to results buffer
 * @param threadsPerBlock Threads per block (typically 256)
 * @return true if kernel launched successfully
 */
bool launch_stride_search(
    uint64_t *d_startPoints,
    const uint32_t *d_targetHash160,
    uint32_t num_threads,
    uint32_t maxFound,
    uint32_t *d_found_results,
    int threadsPerBlock
);

#ifdef __cplusplus
}
#endif

#endif // SEARCH_KERNEL_H
