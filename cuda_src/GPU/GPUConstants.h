/*
 * GPU constants extracted from GPUEngine.h
 * Only the constants needed by ComputeKeysExact and CheckHash160Exact
 */

#ifndef GPUCONSTANTS_H
#define GPUCONSTANTS_H

// Number of keys per thread per kernel call (must be a multiple of GRP_SIZE)
#define STEP_SIZE 1024

// Result item size in bytes and uint32_t units
#define ITEM_SIZE 28
#define ITEM_SIZE32 (ITEM_SIZE/4)

#endif // GPUCONSTANTS_H
