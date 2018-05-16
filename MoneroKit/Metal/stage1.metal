//
//  stage1.metal
//  MoneroMiner
//
//  Created by Yury Popov on 24.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "aes.metal"
#include "keccak.metal"

typedef size_t uint64_t;

constant static const constexpr size_t blobBufferSize = 128;
constant static const constexpr size_t expandedKeySize = 320;
constant static const constexpr size_t stateSize = 256;

kernel void cn_stage1(
                      device uint8_t *blobbuf [[ buffer(0) ]],
                      device uint32_t *bloblenbuf [[ buffer(1) ]],
                      device uint8_t *statebuf [[ buffer(2) ]],
                      device uint8_t *ekeybuf [[ buffer(3) ]],
                      uint idx [[ thread_position_in_grid ]]
                      )
{
  device uint8_t *blob = (blobbuf + idx * blobBufferSize);
  device uint8_t *state = (statebuf + idx * stateSize);
  device uint8_t *expandedKey = (ekeybuf + idx * expandedKeySize);
  uint32_t bloblen = *bloblenbuf;
  
  device uint64_t *nonceptr = (device uint64_t*)(state + 200);
  device uint4 *a = (device uint4*)(state + 208);
  device uint4 *b = (device uint4*)(state + 224);

  keccak1600(blob, bloblen, state);
  
  *nonceptr = 0;
  if (bloblen >= 43) {
    uint64_t x = ((const device uint64_t*)state)[24];
    uint64_t y;
    thread uint8_t *yb = (thread uint8_t*)&y;
    yb[0] = blob[35];
    yb[1] = blob[36];
    yb[2] = blob[37];
    yb[3] = blob[38];
    yb[4] = blob[39];
    yb[5] = blob[40];
    yb[6] = blob[41];
    yb[7] = blob[42];
    *nonceptr = x^y;
  }

  aes_expand_key(expandedKey, state);
  aes_expand_key(expandedKey + 160, &state[32]);
  
  *a = ((device uint4*)state)[0] ^ ((device uint4*)state)[2];
  *b = ((device uint4*)state)[1] ^ ((device uint4*)state)[3];
}

