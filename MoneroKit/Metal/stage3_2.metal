//
//  stage3.metal
//  MoneroMiner
//
//  Created by Yury Popov on 25.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "u64.metal"
#include "aes.metal"
#include "mul128.metal"

constant static const constexpr size_t threadMemorySize = 1 << 21;
constant static const constexpr size_t stateSize = 320;
constant static const constexpr size_t ITER = (1 << 20);

#include "MetalGranularity.h"

static inline __attribute__((always_inline)) void cn_v2_shuffle_add(device uint8_t *hp_state, const thread uint32_t j, const thread uint4 _a, const thread uint4 _b, const thread uint4 _b1) {
  const uint4 chunk1 = *(device uint4*)(hp_state + (j ^ 0x10));
  const uint4 chunk2 = *(device uint4*)(hp_state + (j ^ 0x20));
  const uint4 chunk3 = *(device uint4*)(hp_state + (j ^ 0x30));
  ((thread _uint64_t*)&chunk1)[0] += ((thread _uint64_t*)&_b)[0];
  ((thread _uint64_t*)&chunk1)[1] += ((thread _uint64_t*)&_b)[1];
  ((thread _uint64_t*)&chunk2)[0] += ((thread _uint64_t*)&_a)[0];
  ((thread _uint64_t*)&chunk2)[1] += ((thread _uint64_t*)&_a)[1];
  ((thread _uint64_t*)&chunk3)[0] += ((thread _uint64_t*)&_b1)[0];
  ((thread _uint64_t*)&chunk3)[1] += ((thread _uint64_t*)&_b1)[1];
  *(device uint4*)(hp_state + (j ^ 0x10)) = chunk3;
  *(device uint4*)(hp_state + (j ^ 0x20)) = chunk1;
  *(device uint4*)(hp_state + (j ^ 0x30)) = chunk2;
}

kernel void cn_stage3_n_v2(
                        device uint8_t *statebuf [[ buffer(0) ]],
                        device uint8_t *membuf [[ buffer(1) ]],
                        uint idx [[ thread_position_in_grid ]]
                        )
{
  device uint8_t *state = (statebuf + idx * stateSize);
  device uint8_t *long_state = (membuf + idx * threadMemorySize);
  device uint4 *_a = (device uint4*)(state + 208);
  device uint4 *_b = (device uint4*)(state + 224);
  device uint4 *_b1 = (device uint4*)(state + 240);
  device uint2 *_division_result = (device uint2*)(state + 256);
  device uint2 *_sqrt_result = (device uint2*)(state + 264);
  device uint4 *p;
  
  thread uint4 a = *_a, b = *_b, b1 = *_b1, c, c1, t;
  thread _uint64_t division_result = *(device _uint64_t*)_division_result;
  thread _uint64_t sqrt_result = *(device _uint64_t*)_sqrt_result;
  thread uint32_t j;
  
  for(size_t i = 0; i < ITER / 2 / GRANULARITY; i++) {
    // Iteration 1
    j = a.x & 0x1ffff0;
    p = (device uint4*)&long_state[j];
    c = *p;
    aes_round(c, a);
    cn_v2_shuffle_add(long_state, j, a, b, b1);
    *p = b ^ c;
    
    // Iteration 2
    j = c.x & 0x1ffff0;
    p = (device uint4*)&long_state[j];
    c1 = *p;
    {
      ((thread _uint64_t*)(&c1))[0] ^= division_result ^ (sqrt_result << 32);
      const _uint64_t dividend = ((thread _uint64_t*)(&c))[1];
      const uint32_t divisor = (uint32_t)(((thread _uint64_t*)(&c))[0] + (uint32_t)(sqrt_result << 1)) | 0x80000001UL;
      division_result = ((uint32_t)(dividend / divisor)) + (((_uint64_t)(dividend % divisor)) << 32);
      _uint64_t sqrt_input = ((thread _uint64_t*)(&c))[0] + (_uint64_t)division_result;

      _uint64_t r = 1ULL << 63;
      for (_uint64_t bit = 1ULL << 60; bit; bit >>= 2) {
        if (sqrt_input < r + bit) {
          r = r >> 1;
        } else {
          sqrt_input = (sqrt_input - (r + bit));
          r = (r + bit * 2) >> 1;
        }
      }
      sqrt_result = (uint32_t)(r * 2 + ((sqrt_input > r) ? 1 : 0));
    }
    mul128(*(thread uint2*)&c, *(thread uint2*)&c1, t);
    {
      *(device uint4*)(long_state + (j ^ 0x10)) ^= *((const thread uint4*)&t);
      *(thread uint4*)&t ^= *(const device uint4*)(long_state + (j ^ 0x20));
    }
    cn_v2_shuffle_add(long_state, j, a, b, b1);
    ((thread _uint64_t*)&a)[0] += ((const thread _uint64_t*)&t)[0];
    ((thread _uint64_t*)&a)[1] += ((const thread _uint64_t*)&t)[1];
    *p = a;
    a ^= c1;
    b1 = b;
    b = c;
  }
  
  *_a = a; *_b = b; *_b1 = b1;
  *(device _uint64_t*)_division_result = division_result;
  *(device _uint64_t*)_sqrt_result = sqrt_result;
}
