//
//  stage4.metal
//  MoneroMiner
//
//  Created by Yury Popov on 25.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "aes.metal"

typedef size_t uint64_t;

constant static const constexpr size_t expandedKeySize = 320;
constant static const constexpr size_t threadMemorySize = 1 << 21;
constant static const constexpr size_t stateSize = 256;

kernel void cn_stage4_n(
                        device uint8_t *statebuf [[ buffer(0) ]],
                        device uint8_t *ekeybuf [[ buffer(1) ]],
                        device uint8_t *membuf [[ buffer(2) ]],
                        device uint8_t *partbuf [[ buffer(3) ]],
                        uint2 idx [[ thread_position_in_grid ]]
                        )
{
  device uint4 *state = (device uint4*)(statebuf + idx.x * stateSize) + 4 + idx.y;
  device uint4 *expandedKey = (device uint4*)(ekeybuf + idx.x * expandedKeySize + 160);
  device uint4 *long_state = (device uint4*)(membuf + idx.x * threadMemorySize) + idx.y;
  uint32_t part = (uint32_t)(*partbuf);
  long_state += threadMemorySize / 128 / 16 * 8 * part;
  
  thread uint4 ek[10] = {
    expandedKey[0], expandedKey[1], expandedKey[2], expandedKey[3],
    expandedKey[4], expandedKey[5], expandedKey[6], expandedKey[7],
    expandedKey[8], expandedKey[9]
  };

  uint4 buf = *state;
  
  for (uint32_t i = 0; i < threadMemorySize / 128 / 16; i++) {
    buf ^= *long_state;
    aes_round(buf, ek[0]);
    aes_round(buf, ek[1]);
    aes_round(buf, ek[2]);
    aes_round(buf, ek[3]);
    aes_round(buf, ek[4]);
    aes_round(buf, ek[5]);
    aes_round(buf, ek[6]);
    aes_round(buf, ek[7]);
    aes_round(buf, ek[8]);
    aes_round(buf, ek[9]);
    long_state += 8;
  }
  
  *state = buf;
}
