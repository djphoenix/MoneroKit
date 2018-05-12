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
  [encoder dispatchThreadgroups:MTLSizeMake(self.batchSize / [state threadExecutionWidth], 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 1, 1)];
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
  [encoder dispatchThreadgroups:MTLSizeMake(self.batchSize / [state threadExecutionWidth], 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 8, 1)];
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
  [encoder dispatchThreadgroups:MTLSizeMake(self.batchSize / [state threadExecutionWidth], 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 8, 1)];
  [encoder endEncoding];
  return run(buffer, [self resourceLimit]);
}

static inline NSError* cn_stage3_n(MoneroBackendMetalThread *self) {
  id<MTLComputePipelineState> state = self.computeStates[@"cn_stage3_n"];
  id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
  [buffer setLabel:@"cn_stage3_n"];
  id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
  [encoder setComputePipelineState:state];
  [encoder setBuffer:self.stateBuffer offset:0 atIndex:0];
  [encoder setBuffer:self.memoryBuffer offset:0 atIndex:1];
  [encoder dispatchThreadgroups:MTLSizeMake(self.batchSize / [state threadExecutionWidth], 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 1, 1)];
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
  [encoder dispatchThreadgroups:MTLSizeMake(self.batchSize / [state threadExecutionWidth], 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 8, 1)];
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
  [encoder dispatchThreadgroups:MTLSizeMake(self.batchSize / [state threadExecutionWidth], 1, 1) threadsPerThreadgroup:MTLSizeMake([state threadExecutionWidth], 1, 1)];
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

  MoneroBackendJob *job;
  size_t blob_len;
  uint8_t *blob_ptr;
  uint32_t *nonce_ptr;
  uint32_t nonce;
  struct timeval starttime, endtime;
  useconds_t worktime;
  blob_ptr = self.blobBuffer.contents;

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
#define EXEC_STAGE(x,...) do {\
  if (job != self.job) goto _break;\
  if (!error) error = cn_stage##x(__VA_ARGS__);\
} while(0)

        EXEC_STAGE(1, self);
        EXEC_STAGE(2_0, self);
#pragma clang loop unroll(full)
        for (uint8_t i = 1; i < GRANULARITY; i++) EXEC_STAGE(2_n, self, i);
#pragma clang loop unroll(full)
        for (uint8_t i = 0; i < GRANULARITY; i++) EXEC_STAGE(3_n, self);
#pragma clang loop unroll(full)
        for (uint8_t i = 0; i < GRANULARITY; i++) EXEC_STAGE(4_n, self, i);
        EXEC_STAGE(5, self);
        EXEC_STAGE(6, self);

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
