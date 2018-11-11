//
//  MoneroBackendMetalThread.m
//  MoneroMiner
//
//  Created by Yury Popov on 23.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroBackendMetalThread.h"
#import "MoneroBackend_private.h"

#import <stdatomic.h>
#import <sys/time.h>

#import "hash-ops.h"
#import "keccak.h"

#if !TARGET_OS_SIMULATOR
#include "MoneroMetal.metallib.h"
#else
#warning Metal is not supported in Simulator
static const uint8_t MoneroMetal_metallib[] = {};
#endif

#include "MetalGranularity.h"

static const size_t blobBufferSize = 128;
static const size_t expandedKeySize = 320;
static const size_t threadMemorySize = 1 << 21;
static const size_t hashSize = 32;
static const size_t stateSize = 256;

@interface MoneroBackendMetalThread ()
@property (atomic) size_t batchSize;
@property (atomic, strong) id<MTLLibrary> library;
@property (atomic, strong) NSDictionary<NSString*, id<MTLComputePipelineState>> *computeStates;
@property (atomic, strong) id<MTLCommandQueue> queue;
@property (atomic, strong) id<MTLBuffer> partBuffer;
@property (atomic, strong) id<MTLBuffer> blobBuffer;
@property (atomic, strong) id<MTLBuffer> blobLenBuffer;
@property (atomic, strong) id<MTLBuffer> memoryBuffer;
@property (atomic, strong) id<MTLBuffer> expKeyBuffer;
@property (atomic, strong) id<MTLBuffer> stateBuffer;
@property (atomic, strong) id<MTLBuffer> hashBuffer;
@end

@implementation MoneroBackendMetalThread {
  _Atomic(double) hashrate;
}

static inline NSError* run(id<MTLCommandBuffer> buffer, double limit) {
  struct timeval start, end;
  gettimeofday(&start, nil);
  [buffer commit];
  [buffer waitUntilCompleted];
  gettimeofday(&end, nil);
  useconds_t worktime = (useconds_t)(end.tv_sec - start.tv_sec) * 1000000 + (useconds_t)(end.tv_usec - start.tv_usec);
//  NSLog(@"%@ %@ns", [buffer label], @(worktime));
  if (limit < 1) {
    useconds_t sleeptime = (useconds_t)((double)worktime * (1 - limit));
    usleep(sleeptime);
  }
  return [buffer error];
}

static inline NSError* cn_stage1(MoneroBackendMetalThread *self) {
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage1"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage1"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.blobBuffer offset:0 atIndex:0];
  [encoder setBuffer:self.blobLenBuffer offset:0 atIndex:1];
  [encoder setBuffer:self.stateBuffer offset:0 atIndex:2];
  [encoder setBuffer:self.expKeyBuffer offset:0 atIndex:3];
  [encoder dispatchThreadgroups:MTLSizeMake(MAX(1, self.batchSize / [state threadExecutionWidth]), 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 1, 1)];
  [encoder endEncoding];
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage2_0(MoneroBackendMetalThread *self) {
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage2_0"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage2_0"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.stateBuffer offset:0 atIndex:0];
  [encoder setBuffer:self.expKeyBuffer offset:0 atIndex:1];
  [encoder setBuffer:self.memoryBuffer offset:0 atIndex:2];
  [encoder dispatchThreadgroups:MTLSizeMake(MAX(1, self.batchSize / [state threadExecutionWidth]), 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 8, 1)];
  [encoder endEncoding];
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage2_n(MoneroBackendMetalThread *self, uint8_t n) {
  *(uint8_t*)[self.partBuffer contents] = n;
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage2_n"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage2_n"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.expKeyBuffer offset:0 atIndex:0];
  [encoder setBuffer:self.memoryBuffer offset:0 atIndex:1];
  [encoder setBuffer:self.partBuffer offset:0 atIndex:2];
  [encoder dispatchThreadgroups:MTLSizeMake(MAX(1, self.batchSize / [state threadExecutionWidth]), 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 8, 1)];
  [encoder endEncoding];
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage3_n_v0(MoneroBackendMetalThread *self) {
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage3_n_v0"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage3_n"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.stateBuffer offset:0 atIndex:0];
  [encoder setBuffer:self.memoryBuffer offset:0 atIndex:1];
  [encoder dispatchThreadgroups:MTLSizeMake(MAX(1, self.batchSize / [state threadExecutionWidth]), 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 1, 1)];
  [encoder endEncoding];
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage3_n_v1(MoneroBackendMetalThread *self) {
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage3_n_v1"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage3_n"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.stateBuffer offset:0 atIndex:0];
  [encoder setBuffer:self.memoryBuffer offset:0 atIndex:1];
  [encoder dispatchThreadgroups:MTLSizeMake(MAX(1, self.batchSize / [state threadExecutionWidth]), 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 1, 1)];
  [encoder endEncoding];
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage4_n(MoneroBackendMetalThread *self, uint8_t n) {
  *(uint8_t*)[self.partBuffer contents] = n;
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage4_n"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage4_n"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.stateBuffer offset:0 atIndex:0];
  [encoder setBuffer:self.expKeyBuffer offset:0 atIndex:1];
  [encoder setBuffer:self.memoryBuffer offset:0 atIndex:2];
  [encoder setBuffer:self.partBuffer offset:0 atIndex:3];
  [encoder dispatchThreadgroups:MTLSizeMake(MAX(1, self.batchSize / [state threadExecutionWidth]), 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 8, 1)];
  [encoder endEncoding];
  
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage5(MoneroBackendMetalThread *self) {
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage5"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage5"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.stateBuffer offset:0 atIndex:0];
  [encoder dispatchThreadgroups:MTLSizeMake(MAX(1, self.batchSize / [state threadExecutionWidth]), 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 1, 1)];
  [encoder endEncoding];
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage6(MoneroBackendMetalThread *self) {
  uint8_t *statebuf = self.stateBuffer.contents;
  uint8_t *hashbuf = self.hashBuffer.contents;
  for (size_t i = 0; i < self.batchSize; i++) {
    uint8_t *state = (statebuf + i * stateSize);
    uint8_t *hash = (hashbuf + i * hashSize);
    switch (state[0] & 3) {
      case 0: hash_extra_blake(state, 200, (char*)hash); break;
      case 1: hash_extra_groestl(state, 200, (char*)hash); break;
      case 2: hash_extra_jh(state, 200, (char*)hash); break;
      case 3: hash_extra_skein(state, 200, (char*)hash); break;
    }
  }
  return nil;
}

#define EXEC_STAGE(x,...) do { \
  if (job != self.job) goto _break; \
  if (!error) error = cn_stage##x(__VA_ARGS__); \
} while(0)

#define metal_slow_hash(v) do { \
  EXEC_STAGE(1, self); \
  EXEC_STAGE(2_0, self); \
_Pragma("clang loop unroll(full)") \
  for (i = 1; i < GRANULARITY; i++) EXEC_STAGE(2_n, self, i); \
  if (v > 0) { \
_Pragma("clang loop unroll(full)") \
    for (i = 0; i < GRANULARITY; i++) EXEC_STAGE(3_n_v1, self); \
  } else { \
_Pragma("clang loop unroll(full)") \
    for (i = 0; i < GRANULARITY; i++) EXEC_STAGE(3_n_v0, self); \
  } \
_Pragma("clang loop unroll(full)") \
  for (i = 0; i < GRANULARITY; i++) EXEC_STAGE(4_n, self, i); \
  EXEC_STAGE(5, self); \
  EXEC_STAGE(6, self); \
} while(0)

#if defined DEBUG && DEBUG
- (void)performTests {
  NSError *error = nil;
  uint8_t i;
  MoneroBackendJob *job = [self job];
  size_t batch = self.batchSize;
  self.batchSize = 1;

  uint8_t *blob_ptr = self.blobBuffer.contents;
  *((uint32_t*)self.blobLenBuffer.contents) = 21;
  for (size_t i = 0; i < self.batchSize; i++) {
    memcpy(blob_ptr + i * blobBufferSize, (const uint8_t[]){0x64, 0x65, 0x20, 0x6f, 0x6d, 0x6e, 0x69, 0x62, 0x75, 0x73, 0x20, 0x64, 0x75, 0x62, 0x69, 0x74, 0x61, 0x6e, 0x64, 0x75, 0x6d}, 21);
  }
  metal_slow_hash(0);
  if (memcmp(self.hashBuffer.contents, (const uint8_t[]){ 0x2f, 0x8e, 0x3d, 0xf4, 0x0b, 0xd1, 0x1f, 0x9a, 0xc9, 0x0c, 0x74, 0x3c, 0xa8, 0xe3, 0x2b, 0xb3, 0x91, 0xda, 0x4f, 0xb9, 0x86, 0x12, 0xaa, 0x3b, 0x6c, 0xdc, 0x63, 0x9e, 0xe0, 0x0b, 0x31, 0xf5 }, 32) == 0) {
    NSLog(@"Metal[%@]: V0 passed", [self.device name]);
  } else {
    NSLog(@"Metal[%@]: V0 failed", [self.device name]);
  }

  *((uint32_t*)self.blobLenBuffer.contents) = 96;
  for (size_t i = 0; i < self.batchSize; i++) {
    memcpy(blob_ptr + i * blobBufferSize, (const uint8_t[]){0x37, 0xa6, 0x36, 0xd7, 0xda, 0xfd, 0xf2, 0x59, 0xb7, 0x28, 0x7e, 0xdd, 0xca, 0x2f, 0x58, 0x09, 0x9e, 0x98, 0x61, 0x9d, 0x2f, 0x99, 0xbd, 0xb8, 0x96, 0x9d, 0x7b, 0x14, 0x49, 0x81, 0x02, 0xcc, 0x06, 0x52, 0x01, 0xc8, 0xbe, 0x90, 0xbd, 0x77, 0x73, 0x23, 0xf4, 0x49, 0x84, 0x8b, 0x21, 0x5d, 0x29, 0x77, 0xc9, 0x2c, 0x4c, 0x1c, 0x2d, 0xa3, 0x6a, 0xb4, 0x6b, 0x2e, 0x38, 0x96, 0x89, 0xed, 0x97, 0xc1, 0x8f, 0xec, 0x08, 0xcd, 0x3b, 0x03, 0x23, 0x5c, 0x5e, 0x4c, 0x62, 0xa3, 0x7a, 0xd8, 0x8c, 0x7b, 0x67, 0x93, 0x24, 0x95, 0xa7, 0x10, 0x90, 0xe8, 0x5d, 0xd4, 0x02, 0x0a, 0x93, 0x00}, 96);
  }
  metal_slow_hash(1);
  if (memcmp(self.hashBuffer.contents, (const uint8_t[]){ 0x61, 0x3e, 0x63, 0x85, 0x05, 0xba, 0x1f, 0xd0, 0x5f, 0x42, 0x8d, 0x5c, 0x9f, 0x8e, 0x08, 0xf8, 0x16, 0x56, 0x14, 0x34, 0x2d, 0xac, 0x41, 0x9a, 0xdc, 0x6a, 0x47, 0xdc, 0xe2, 0x57, 0xeb, 0x3e }, 32) == 0) {
    NSLog(@"Metal[%@]: V1 passed", [self.device name]);
  } else {
    NSLog(@"Metal[%@]: V1 failed", [self.device name]);
  }

  self.batchSize = batch;
  return;
_break:
  self.batchSize = batch;
  NSLog(@"Test error: %@", error);
}
#endif

- (void)main {
  NSError *error = nil;

  self.library = [self.device newLibraryWithData:dispatch_data_create(MoneroMetal_metallib, sizeof(MoneroMetal_metallib), nil, nil) error:&error];
  if (error) {
    NSLog(@"[Load] Error: %@", error);
    return;
  }
  
  if ([[self.device name] isEqualToString:@"Intel HD Graphics 4000"] ||
      [[self.device name] isEqualToString:@"Apple A8 GPU"]) {
    self.batchSize = 32;
  } else if ([[self.device name] isEqualToString:@"Apple A11 GPU"]) {
    self.batchSize = 256;
  } else {
    self.batchSize = 128;
  }

  NSMutableDictionary *states = [NSMutableDictionary new];
  for (NSString *name in [self.library functionNames]) {
    id<MTLFunction> func = [self.library newFunctionWithName:name];
    if ([func functionType] != MTLFunctionTypeKernel) continue;
    id<MTLComputePipelineState> state = [self.device newComputePipelineStateWithFunction:func error:&error];
    if (error) {
      NSLog(@"[Compile: %@] Error: %@", [func name], error);
      return;
    }
    [states setObject:state forKey:name];
  }
  
  self.computeStates = [NSDictionary dictionaryWithDictionary:states];
  
  self.blobBuffer = [self.device newBufferWithLength:self.batchSize * blobBufferSize options:MTLResourceStorageModeShared];
  self.blobLenBuffer = [self.device newBufferWithLength:4 options:MTLResourceStorageModeShared];
  self.memoryBuffer = [self.device newBufferWithLength:self.batchSize * threadMemorySize options:MTLResourceStorageModeShared];
  self.hashBuffer = [self.device newBufferWithLength:self.batchSize * hashSize options:MTLResourceStorageModeShared];
  self.expKeyBuffer = [self.device newBufferWithLength:self.batchSize * expandedKeySize options:MTLResourceStorageModeShared];
  self.stateBuffer = [self.device newBufferWithLength:self.batchSize * stateSize options:MTLResourceStorageModeShared];
  self.partBuffer = [self.device newBufferWithLength:1 options:MTLResourceStorageModeShared];
  self.queue = [self.device newCommandQueue];
  if (!self.blobBuffer ||
      !self.blobLenBuffer ||
      !self.memoryBuffer ||
      !self.hashBuffer ||
      !self.expKeyBuffer ||
      !self.stateBuffer ||
      !self.queue) {
    NSLog(@"Error: cannot allocate buffer");
    return;
  }

  NSLog(@"Metal thread: %@, batch size: %@", [self.device name], @(self.batchSize));

#if defined DEBUG && DEBUG
  [self performTests];
#endif

  MoneroBackendJob *job;
  size_t blob_len;
  uint8_t *blob_ptr;
  uint32_t *nonce_ptr;
  uint32_t nonce;
  struct timeval starttime, endtime;
  useconds_t worktime;
  blob_ptr = self.blobBuffer.contents;
  uint64_t version;
  uint8_t i;

  while (![self isCancelled]) {
    job = [self job];
    if (job == nil) {
      atomic_store(&hashrate, 0);
      [NSThread sleepForTimeInterval:0.01];
      continue;
    }
    
    blob_len = (size_t)job.blob.length;
    *((uint32_t*)self.blobLenBuffer.contents) = (uint32_t)blob_len;
    for (size_t i = 0; i < self.batchSize; i++) {
      [job.blob getBytes:(blob_ptr + i * blobBufferSize) length:blob_len];
    }
    version = job.versionMajor > 6 ? job.versionMajor - 6 : 0;

    while (![self isCancelled]) {
      if (job != self.job) break;

      if (self.resourceLimit <= 0) {
        atomic_store(&hashrate, 0);
        [NSThread sleepForTimeInterval:0.05];
        continue;
      }

      gettimeofday(&starttime, nil);
      
      nonce = [self nonceBlock];
      for (size_t i = 0; i < self.batchSize; i++) {
        nonce_ptr = (uint32_t*)(blob_ptr + i * blobBufferSize + job.nonceOffset);
        memmove(nonce_ptr, &nonce, sizeof(nonce));
        nonce ++;
      }
      {
        error = nil;
        metal_slow_hash(version);
        if (error) {
          NSLog(@"%@", error);
          atomic_store(&hashrate, 0);
          [NSThread sleepForTimeInterval:0.5];
          break;
        }
      }
      gettimeofday(&endtime, nil);
      [self validateHashes:job];
      worktime = (useconds_t)(endtime.tv_sec - starttime.tv_sec) * 1000000 + (useconds_t)(endtime.tv_usec - starttime.tv_usec);
      atomic_store(&hashrate, ((double)self.batchSize * (double)1000000 / (double)worktime));
    _break: ;
    }
  }
}

- (void)validateHashes:(MoneroBackendJob*)job {
  uint8_t *blobbuf = self.blobBuffer.contents;
  uint8_t *hashbuf = self.hashBuffer.contents;
  uint32_t nonce;
  for (size_t i = 0; i < self.batchSize; i++) {
//    {
//      uint8_t hash_test[32];
//      cn_slow_hash(blobbuf + i * blobBufferSize, job.blob.length, hash_test, self.memoryBuffer.contents);
//      if (memcmp(hash_test, hashbuf + i * hashSize, 32) != 0) {
//        NSLog(@"HASH %@ MISMATCH", @(i));
//        continue;
//      }
//    }
    if (((uint64_t*)(hashbuf + i * hashSize))[3] < job.target) {
      memmove(&nonce, blobbuf + i * blobBufferSize + job.nonceOffset, sizeof(nonce));
      [self handleResult:(const struct MoneroHash *)(hashbuf + i * hashSize) withNonce:nonce forJob:job.jobId];
    }
  }
}

- (double)hashRate {
  return atomic_load(&hashrate);
}

- (uint32_t)nonceBlock {
  __strong MoneroBackend *backend = [self backend];
  if (!backend) return 0;
  return [backend nextNonceBlock:(uint32_t)self.batchSize];
}

- (double)resourceLimit {
  __strong MoneroBackend *backend = [self backend];
  if (!backend) return 0;
  return [backend metalLimit];
}

- (MoneroBackendJob*)job {
  __strong MoneroBackend *backend = [self backend];
  if (!backend) return nil;
  return [backend currentJob];
}

- (void)handleResult:(const struct MoneroHash*)hash withNonce:(uint32_t)nonce forJob:(NSString*)jobId {
  __strong MoneroBackend *backend = [self backend];
  [backend handleResult:hash withNonce:nonce forJob:jobId];
}

@end
