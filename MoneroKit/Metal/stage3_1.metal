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

static constant const uint32_t v1_table = 0x75310;

kernel void cn_stage3_n_v1(
                        device uint8_t *statebuf [[ buffer(0) ]],
                        device uint8_t *membuf [[ buffer(1) ]],
                        uint idx [[ thread_position_in_grid ]]
                        )
{
  device uint8_t *state = (statebuf + idx * stateSize);
  device uint8_t *long_state = (membuf + idx * threadMemorySize);
  device uint2 *nonceptr = (device uint2*)(state + 200);
  device uint4 *_a = (device uint4*)(state + 208);
  device uint4 *_b = (device uint4*)(state + 224);
  device uint4 *p;
  uint2 nonce = *nonceptr;
  
  uint4 a = *_a, b = *_b, c, t;
  
  uint8_t tmp, tmp0;
  uint32_t j;
  
  for(size_t i = 0; i < ITER / 2 / GRANULARITY; i++) {
    j = a.x & 0x1ffff0;
    // Iteration 1
    p = (device uint4*)&long_state[j];
    c = *p;
    aes_round(c, a);
    b ^= c;
    *p = b;

    tmp = long_state[j+11];
    tmp0 = (uint8_t)((((tmp >> 3) & 6) | (tmp & 1)) << 1);
    long_state[j+11] = tmp ^ ((v1_table >> tmp0) & 0x30);

    // Iteration 2

    j = c.x & 0x1ffff0;
    p = (device uint4*)&long_state[j];
    b = *p;
    mul128(*(thread uint2*)&c, *(thread uint2*)&b, t);
    ((thread _uint64_t*)&a)[0] += ((const thread _uint64_t*)&t)[0];
    ((thread _uint64_t*)&a)[1] += ((const thread _uint64_t*)&t)[1];
    *p = a;
    a ^= b;
    *(device uint2*)(long_state + j + 8) ^= nonce;
    b = c;
  }
  
  *_a = a; *_b = b;
}
