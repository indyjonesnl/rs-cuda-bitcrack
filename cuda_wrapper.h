/*
 * CUDA Wrapper for Rust FFI
 * Provides C-compatible interface to CUDA secp256k1 implementation
 */

#ifndef CUDA_WRAPPER_H
#define CUDA_WRAPPER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize GPU context
bool gpu_init(int device_id);

// Cleanup GPU resources
void gpu_cleanup();

// Search for address in range
// Returns true if found, and sets private_key_out to the found key
bool gpu_search_address(
    const char* target_address,
    const uint8_t* range_min,  // 32 bytes
    const uint8_t* range_max,  // 32 bytes
    uint8_t* private_key_out   // 32 bytes output buffer
);

// Generate address from private key (for testing)
// Only P2PKH addresses are supported
bool gpu_generate_address(
    const uint8_t* private_key,  // 32 bytes
    char* address_out,           // Output buffer (at least 35 bytes)
    int address_type             // 0 = P2PKH (only option)
);

// Get GPU device info
typedef struct {
    char name[256];
    int compute_capability_major;
    int compute_capability_minor;
    size_t total_memory;
    int multiprocessor_count;
} GpuDeviceInfo;

bool gpu_get_device_info(int device_id, GpuDeviceInfo* info);

#ifdef __cplusplus
}
#endif

#endif // CUDA_WRAPPER_H
