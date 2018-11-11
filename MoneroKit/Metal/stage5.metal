//
//  stage5.metal
//  MoneroMiner
//
//  Created by Yury Popov on 03.01.2018.
//  Copyright © 2018 PhoeniX. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "keccak.metal"

constant static const constexpr size_t stateSize = 256;

kernel void cn_stage5(
                      device uint8_t *statebuf [[ buffer(0) ]],
                      uint idx [[ thread_position_in_grid ]]
                      )
{
  device uint8_t *state = (statebuf + idx * stateSize);
  state_t st;
  ((thread uint4*)st)[0] = ((device uint4*)state)[0];
  ((thread uint4*)st)[1] = ((device uint4*)state)[1];
  ((thread uint4*)st)[2] = ((device uint4*)state)[2];
  ((thread uint4*)st)[3] = ((device uint4*)state)[3];
  ((thread uint4*)st)[4] = ((device uint4*)state)[4];
  ((thread uint4*)st)[5] = ((device uint4*)state)[5];
  ((thread uint4*)st)[6] = ((device uint4*)state)[6];
  ((thread uint4*)st)[7] = ((device uint4*)state)[7];
  ((thread uint4*)st)[8] = ((device uint4*)state)[8];
  ((thread uint4*)st)[9] = ((device uint4*)state)[9];
  ((thread uint4*)st)[10] = ((device uint4*)state)[10];
  ((thread uint4*)st)[11] = ((device uint4*)state)[11];
  ((thread uint2*)st)[24] = ((device uint2*)state)[24];
  keccakf(st, 24);
  ((device uint4*)state)[0] = ((thread uint4*)st)[0];
  ((device uint4*)state)[1] = ((thread uint4*)st)[1];
  ((device uint4*)state)[2] = ((thread uint4*)st)[2];
  ((device uint4*)state)[3] = ((thread uint4*)st)[3];
  ((device uint4*)state)[4] = ((thread uint4*)st)[4];
  ((device uint4*)state)[5] = ((thread uint4*)st)[5];
  ((device uint4*)state)[6] = ((thread uint4*)st)[6];
  ((device uint4*)state)[7] = ((thread uint4*)st)[7];
  ((device uint4*)state)[8] = ((thread uint4*)st)[8];
  ((device uint4*)state)[9] = ((thread uint4*)st)[9];
  ((device uint4*)state)[10] = ((thread uint4*)st)[10];
  ((device uint4*)state)[11] = ((thread uint4*)st)[11];
  ((device uint2*)state)[24] = ((thread uint2*)st)[24];
}
