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

#include "MetalGranularity.h"

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

static constant const uint32_t v1_table = 0x75310;

kernel void cn_stage3_n_v1(
                        device uint8_t *statebuf [[ buffer(0) ]],
                        device uint8_t *membuf [[ buffer(1) ]],
                        uint idx [[ thread_position_in_grid ]]
                        )
{
  device uint8_t *state = (statebuf + idx * stateSize);
  device uint8_t *long_state = (membuf + idx * threadMemorySize);
  device uint64_t *nonceptr = (device uint64_t*)(state + 200);
  device uint4 *_a = (device uint4*)(state + 208);
  device uint4 *_b = (device uint4*)(state + 224);
  device uint4 *_c = (device uint4*)(state + 240);
  device uint4 *p;
  uint64_t nonce = *nonceptr;
  
  uint4 a = *_a, b = *_b, c = *_c, t;
  
  uint8_t tmp, tmp0;
  
  for(size_t i = 0; i < ITER / 2 / GRANULARITY; i++) {
    size_t j = a.x & 0x1ffff0;
    // Iteration 1
    p = (device uint4*)&long_state[j];
    c = *p;
    aes_round(c, a);
    b ^= c;
    *p = b;

    j += 11;
    tmp = long_state[j];
    tmp0 = (((tmp >> 3) & 6) | (tmp & 1)) << 1;
    long_state[j] = tmp ^ ((v1_table >> tmp0) & 0x30);

    // Iteration 2
    j = c.x & 0x1ffff0;
    p = (device uint4*)&long_state[j];
    b = *p;
    mul128(*(thread uint2*)&c, *(thread uint2*)&b, t);
    ((thread uint64_t*)&a)[0] += ((const thread uint64_t*)&t)[0];
    ((thread uint64_t*)&a)[1] += ((const thread uint64_t*)&t)[1];
    *p = a;
    a ^= b;
    b = c;
    
    j += 8;
    *(device uint64_t*)(long_state + j) ^= nonce;
  }
  
  *_a = a; *_b = b; *_c = c;
}
