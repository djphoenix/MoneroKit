//
//  stage3.metal
//  MoneroMiner
//
//  Created by Yury Popov on 25.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "aes.metal"

typedef size_t uint64_t;

constant static const constexpr size_t threadMemorySize = 1 << 21;
constant static const constexpr size_t stateSize = 256;
constant static const constexpr size_t ITER = (1 << 20);

static inline __attribute__((always_inline)) void mul128(const uint2 ca, const uint2 cb, thread uint4 &cres) {
  uint64_t ltmp[4];
  thread uint32_t *tmp = (thread uint32_t*)ltmp;

  uint64_t A = ca.y;
  uint64_t a = ca.x;
  uint64_t B = cb.y;
  uint64_t b = cb.x;
  
  ltmp[0] = a * b;
  ltmp[1] = a * B;
  ltmp[2] = A * b;
  ltmp[3] = A * B;
  
  ltmp[1] += tmp[1];
  ltmp[1] += tmp[4];
  ltmp[3] += tmp[3];
  ltmp[3] += tmp[5];
  cres = uint4(tmp[6], tmp[7], tmp[0], tmp[2]);
}

kernel void cn_stage3_n(
                        device uint8_t *statebuf [[ buffer(0) ]],
                        device uint8_t *membuf [[ buffer(1) ]],
                        uint idx [[ thread_position_in_grid ]]
                        )
{
  device uint8_t *state = (statebuf + idx * stateSize);
  device uint8_t *long_state = (membuf + idx * threadMemorySize);
  device uint4 *_a = (device uint4*)(state + 208);
  device uint4 *_b = (device uint4*)(state + 224);
  device uint4 *_c = (device uint4*)(state + 240);
  device uint4 *p;
  
  uint4 a = *_a, b = *_b, c = *_c, t;
  
  for(size_t i = 0; i < ITER / 2 / 16; i++) {
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
    ((thread uint64_t*)&a)[0] += ((const thread uint64_t*)&t)[0];
    ((thread uint64_t*)&a)[1] += ((const thread uint64_t*)&t)[1];
    *p = a;
    a ^= b;
    b = c;
  }
  
  *_a = a; *_b = b; *_c = c;
}
