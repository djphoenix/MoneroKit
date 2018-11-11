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
constant static const constexpr size_t stateSize = 256;
constant static const constexpr size_t ITER = (1 << 20);

#include "MetalGranularity.h"

kernel void cn_stage3_n_v0(
                        device uint8_t *statebuf [[ buffer(0) ]],
                        device uint8_t *membuf [[ buffer(1) ]],
                        uint idx [[ thread_position_in_grid ]]
                        )
{
  device uint8_t *state = (statebuf + idx * stateSize);
  device uint8_t *long_state = (membuf + idx * threadMemorySize);
  device uint4 *_a = (device uint4*)(state + 208);
  device uint4 *_b = (device uint4*)(state + 224);
  device uint4 *p;
  
  uint4 a = *_a, b = *_b, c, t;
  
  for(size_t i = 0; i < ITER / 2 / GRANULARITY; i++) {
    // Iteration 1
    p = (device uint4*)&long_state[a.x & 0x1ffff0];
    c = *p;
    aes_round(c, a);
    b ^= c;
    *p = b;
    
    // Iteration 2
    p = (device uint4*)&long_state[c.x & 0x1ffff0];
    b = *p;
    mul128(*(thread uint2*)&c, *(thread uint2*)&b, t);
    ((thread _uint64_t*)&a)[0] += ((const thread _uint64_t*)&t)[0];
    ((thread _uint64_t*)&a)[1] += ((const thread _uint64_t*)&t)[1];
    *p = a;
    a ^= b;
    b = c;
  }
  
  *_a = a; *_b = b;
}
