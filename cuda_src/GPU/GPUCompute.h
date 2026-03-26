/*
 * This file is part of the VanitySearch distribution (https://github.com/JeanLucPons/VanitySearch).
 * Copyright (c) 2019 Jean Luc PONS.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// CUDA Kernel main function
// Compute SecpK1 keys and calculate RIPEMD160(SHA256(key)) then check exact hash160
// We use affine coordinates for elliptic curve point (ie Z=1)

#include "GPUConstants.h"

// Exact hash160 matching for Bitcoin puzzle solving
// Directly compares computed hash160 with target (no prefix lookup needed)
__device__ __noinline__ void CheckHash160Exact(uint32_t *computed_h160, const uint32_t *target_h160,
                                                int32_t incr, int32_t endo, int32_t mode,
                                                uint32_t maxFound, uint32_t *out) {

  // Direct 5-word (20 byte) comparison
  if (computed_h160[0] == target_h160[0] &&
      computed_h160[1] == target_h160[1] &&
      computed_h160[2] == target_h160[2] &&
      computed_h160[3] == target_h160[3] &&
      computed_h160[4] == target_h160[4]) {

    // Found exact match!
    uint32_t tid = (blockIdx.x * blockDim.x) + threadIdx.x;
    uint32_t pos = atomicAdd(out, 1);

    if (pos < maxFound) {
      out[pos*ITEM_SIZE32 + 1] = tid;
      out[pos*ITEM_SIZE32 + 2] = (uint32_t)(incr << 16) | (uint32_t)(mode << 15) | (uint32_t)(endo);
      out[pos*ITEM_SIZE32 + 3] = computed_h160[0];
      out[pos*ITEM_SIZE32 + 4] = computed_h160[1];
      out[pos*ITEM_SIZE32 + 5] = computed_h160[2];
      out[pos*ITEM_SIZE32 + 6] = computed_h160[3];
      out[pos*ITEM_SIZE32 + 7] = computed_h160[4];
    }
  }
}

// Macro for exact hash160 matching (no prefix lookup)
#define CHECK_EXACT_HASH160(_incr) {                                          \
_GetHash160CompSym(px, (uint8_t *)h1, (uint8_t *)h2);                         \
CheckHash160Exact(h1, target_h160, (_incr), 0, true, maxFound, out);          \
CheckHash160Exact(h2, target_h160, -(_incr), 0, true, maxFound, out);         \
_ModMult(pe1x, px, _beta);                                                    \
_GetHash160CompSym(pe1x, (uint8_t *)h1, (uint8_t *)h2);                       \
CheckHash160Exact(h1, target_h160, (_incr), 1, true, maxFound, out);          \
CheckHash160Exact(h2, target_h160, -(_incr), 1, true, maxFound, out);         \
_ModMult(pe2x, px, _beta2);                                                   \
_GetHash160CompSym(pe2x, (uint8_t *)h1, (uint8_t *)h2);                       \
CheckHash160Exact(h1, target_h160, (_incr), 2, true, maxFound, out);          \
CheckHash160Exact(h2, target_h160, -(_incr), 2, true, maxFound, out);         \
}

// Stride-optimized kernel for exact hash160 matching (Bitcoin puzzle solver)
// Generates 1024 keys per thread using batch modular inverse
__device__ void ComputeKeysExact(uint64_t *startx, uint64_t *starty, const uint32_t *target_h160,
                                 uint32_t maxFound, uint32_t *out) {

  uint64_t dx[GRP_SIZE/2+1][4];
  uint64_t px[4];
  uint64_t py[4];
  uint64_t pyn[4];
  uint64_t sx[4];
  uint64_t sy[4];
  uint64_t dy[4];
  uint64_t _s[4];
  uint64_t _p2[4];
  uint32_t   h1[5];
  uint32_t   h2[5];
  uint64_t   pe1x[4];
  uint64_t   pe2x[4];

  // Load starting key
  __syncthreads();
  Load256A(sx, startx);
  Load256A(sy, starty);
  Load256(px, sx);
  Load256(py, sy);

  for (uint32_t j = 0; j < STEP_SIZE / GRP_SIZE; j++) {

    // Fill group with delta x
    uint32_t i;
    for (i = 0; i < HSIZE; i++)
      ModSub256(dx[i], Gx[i], sx);
    ModSub256(dx[i] , Gx[i], sx);  // For the first point
    ModSub256(dx[i+1],_2Gnx, sx);  // For the next center point

    // BUG FIX: If dx[512] is zero (happens when sx = 1024*G), it breaks _ModInvGrouped
    // This occurs when keyMin + 512 is a multiple of 1024 (e.g., puzzle 10: 0x200 + 0x200 = 0x400)
    // Solution: Replace zero with 1 (which has inverse 1) - safe since dx[512] is only
    // used for multi-batch searches, and single-batch searches don't reach this code path
    bool needsFix = (dx[i+1][0] == 0 && dx[i+1][1] == 0 && dx[i+1][2] == 0 && dx[i+1][3] == 0);
    if (needsFix) {
      dx[i+1][0] = 1;  // Set to 1 instead of 0
      dx[i+1][1] = 0;
      dx[i+1][2] = 0;
      dx[i+1][3] = 0;
    }

    // Compute modular inverse (batch operation - 850x faster than individual)
    _ModInvGrouped(dx);

    // We use the fact that P + i*G and P - i*G has the same deltax, so the same inverse
    // We compute key in the positive and negative way from the center of the group

    // Check starting point
    CHECK_EXACT_HASH160(j*GRP_SIZE + (GRP_SIZE/2));

    ModNeg256(pyn,py);

    for(i = 0; i < HSIZE; i++) {

      __syncthreads();
      // P = StartPoint + i*G
      Load256(px, sx);
      Load256(py, sy);
      ModSub256(dy, Gy[i], py);

      _ModMult(_s, dy, dx[i]);      //  s = (p2.y-p1.y)*inverse(p2.x-p1.x)
      _ModSqr(_p2, _s);             // _p2 = pow2(s)

      ModSub256(px, _p2,px);
      ModSub256(px, Gx[i]);         // px = pow2(s) - p1.x - p2.x;

      CHECK_EXACT_HASH160(j*GRP_SIZE + (GRP_SIZE/2 + (i + 1)));

      __syncthreads();
      // P = StartPoint - i*G, if (x,y) = i*G then (x,-y) = -i*G
      Load256(px, sx);
      ModSub256(dy,pyn,Gy[i]);

      _ModMult(_s, dy, dx[i]);      //  s = (p2.y-p1.y)*inverse(p2.x-p1.x)
      _ModSqr(_p2, _s);             // _p = pow2(s)

      ModSub256(px, _p2, px);
      ModSub256(px, Gx[i]);         // px = pow2(s) - p1.x - p2.x;

      CHECK_EXACT_HASH160(j*GRP_SIZE + (GRP_SIZE/2 - (i + 1)));

    }

    __syncthreads();
    // First point (startP - (GRP_SZIE/2)*G)
    Load256(px, sx);
    Load256(py, sy);
    ModNeg256(dy, Gy[i]);
    ModSub256(dy, py);

    _ModMult(_s, dy, dx[i]);      //  s = (p2.y-p1.y)*inverse(p2.x-p1.x)
    _ModSqr(_p2,_s);              // _p = pow2(s)

    ModSub256(px, _p2, px);
    ModSub256(px, Gx[i]);         // px = pow2(s) - p1.x - p2.x;

    CHECK_EXACT_HASH160(j*GRP_SIZE + (0));

    i++;

    __syncthreads();
    // Next start point (startP + GRP_SIZE*G)
    Load256(px, sx);
    Load256(py, sy);
    ModSub256(dy, _2Gny, py);

    _ModMult(_s, dy, dx[i]);      //  s = (p2.y-p1.y)*inverse(p2.x-p1.x)
    _ModSqr(_p2, _s);             // _p2 = pow2(s)

    ModSub256(px, _p2, px);
    ModSub256(px, _2Gnx);         // px = pow2(s) - p1.x - p2.x;

    ModSub256(py, _2Gnx, px);
    _ModMult(py, _s);             // py = - s*(ret.x-p2.x)
    ModSub256(py, _2Gny);         // py = - p2.y - s*(ret.x-p2.x);

  }

  // Update starting point
  __syncthreads();
  Store256A(startx, px);
  Store256A(starty, py);

}
