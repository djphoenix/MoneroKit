//
//  MoneroCPUBackend.m
//  MoneroKit
//
//  Created by Yury Popov on 10.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroBackendCPUThread.h"

#import <stdatomic.h>
#import <sys/time.h>
#import "MoneroBackend_private.h"
#import "hash-ops.h"

@implementation MoneroBackendCPUThread {
  _Atomic(double) hashrate;
  _Atomic(uint32_t) ratecount;
}

#if defined DEBUG && DEBUG
static void performTests() {
  __attribute__((aligned(16))) struct MoneroHash hash;
  void *hashbuf = cn_slow_hash_alloc();

  cn_slow_hash((const uint8_t[]){0x64, 0x65, 0x20, 0x6f, 0x6d, 0x6e, 0x69, 0x62, 0x75, 0x73, 0x20, 0x64, 0x75, 0x62, 0x69, 0x74, 0x61, 0x6e, 0x64, 0x75, 0x6d}, 21, (char*)hash.bytes, hashbuf, 0);
  if (memcmp(hash.bytes, (const uint8_t[]){ 0x2f, 0x8e, 0x3d, 0xf4, 0x0b, 0xd1, 0x1f, 0x9a, 0xc9, 0x0c, 0x74, 0x3c, 0xa8, 0xe3, 0x2b, 0xb3, 0x91, 0xda, 0x4f, 0xb9, 0x86, 0x12, 0xaa, 0x3b, 0x6c, 0xdc, 0x63, 0x9e, 0xe0, 0x0b, 0x31, 0xf5 }, 32) == 0) {
    NSLog(@"CPU: V0 passed");
  } else {
    NSLog(@"CPU: V0 failed");
  }

  cn_slow_hash((const uint8_t[]){0x37, 0xa6, 0x36, 0xd7, 0xda, 0xfd, 0xf2, 0x59, 0xb7, 0x28, 0x7e, 0xdd, 0xca, 0x2f, 0x58, 0x09, 0x9e, 0x98, 0x61, 0x9d, 0x2f, 0x99, 0xbd, 0xb8, 0x96, 0x9d, 0x7b, 0x14, 0x49, 0x81, 0x02, 0xcc, 0x06, 0x52, 0x01, 0xc8, 0xbe, 0x90, 0xbd, 0x77, 0x73, 0x23, 0xf4, 0x49, 0x84, 0x8b, 0x21, 0x5d, 0x29, 0x77, 0xc9, 0x2c, 0x4c, 0x1c, 0x2d, 0xa3, 0x6a, 0xb4, 0x6b, 0x2e, 0x38, 0x96, 0x89, 0xed, 0x97, 0xc1, 0x8f, 0xec, 0x08, 0xcd, 0x3b, 0x03, 0x23, 0x5c, 0x5e, 0x4c, 0x62, 0xa3, 0x7a, 0xd8, 0x8c, 0x7b, 0x67, 0x93, 0x24, 0x95, 0xa7, 0x10, 0x90, 0xe8, 0x5d, 0xd4, 0x02, 0x0a, 0x93, 0x00}, 96, (char*)hash.bytes, hashbuf, 1);
  if (memcmp(hash.bytes, (const uint8_t[]){ 0x61, 0x3e, 0x63, 0x85, 0x05, 0xba, 0x1f, 0xd0, 0x5f, 0x42, 0x8d, 0x5c, 0x9f, 0x8e, 0x08, 0xf8, 0x16, 0x56, 0x14, 0x34, 0x2d, 0xac, 0x41, 0x9a, 0xdc, 0x6a, 0x47, 0xdc, 0xe2, 0x57, 0xeb, 0x3e }, 32) == 0) {
    NSLog(@"CPU: V1 passed");
  } else {
    NSLog(@"CPU: V1 failed");
  }

  cn_slow_hash((const uint8_t[]){0x69, 0x72, 0x75, 0x72, 0x65, 0x20, 0x64, 0x6f, 0x6c, 0x6f, 0x72, 0x20, 0x69, 0x6e, 0x20, 0x72, 0x65, 0x70, 0x72, 0x65, 0x68, 0x65, 0x6e, 0x64, 0x65, 0x72, 0x69, 0x74, 0x20, 0x69, 0x6e, 0x20, 0x76, 0x6f, 0x6c, 0x75, 0x70, 0x74, 0x61, 0x74, 0x65, 0x20, 0x76, 0x65, 0x6c, 0x69, 0x74}, 47, (char*)hash.bytes, hashbuf, 2);
  if (memcmp(hash.bytes, (const uint8_t[]){ 0x42, 0x2f, 0x8c, 0xfe, 0x80, 0x60, 0xcf, 0x6c, 0x3d, 0x9f, 0xd6, 0x6f, 0x68, 0xe3, 0xc9, 0x97, 0x7a, 0xdb, 0x68, 0x3a, 0xea, 0x27, 0x88, 0x02, 0x93, 0x08, 0xbb, 0xe9, 0xbc, 0x50, 0xd7, 0x28 }, 32) == 0) {
    NSLog(@"CPU: V2 passed");
  } else {
    NSLog(@"CPU: V2 failed");
  }

  free(hashbuf);
}

+ (void)load {
  performTests();
}
#endif

- (void)main {
  __attribute__((aligned(16))) uint8_t blob_buffer[128];
  __attribute__((aligned(16))) struct MoneroHash hash;
  uint32_t *nonce_ptr;
  uint32_t blob_len;
  uint32_t nonce;
  uint64_t target;
  MoneroBackendJob *job;
  double limit;
  struct timeval starttime, endtime;
  useconds_t worktime, sleeptime;
  uint64_t version;
  
  void *hashbuf = cn_slow_hash_alloc();

  while (![self isCancelled]) {
    job = [self job];
    if (job == nil) {
      atomic_store(&hashrate, 0);
      atomic_store(&ratecount, 0);
      [NSThread sleepForTimeInterval:0.01];
      continue;
    }
    
    blob_len = (uint32_t)job.blob.length;
    [job.blob getBytes:blob_buffer length:sizeof(blob_buffer)];
    nonce_ptr = (uint32_t*)(blob_buffer + job.nonceOffset);
    target = job.target;
    version = job.versionMajor > 6 ? job.versionMajor - 6 : 0;
    while (![self isCancelled]) {
      if (job != self.job) break;
      limit = self.resourceLimit;
      if (limit <= 0) {
        atomic_store(&hashrate, 0);
        atomic_store(&ratecount, 0);
        [NSThread sleepForTimeInterval:0.05];
        continue;
      }
      gettimeofday(&starttime, nil);
      nonce = [self nonce];
      memmove(nonce_ptr, &nonce, sizeof(nonce));
      cn_slow_hash(blob_buffer, blob_len, (char*)hash.bytes, hashbuf, version);
      gettimeofday(&endtime, nil);
      if (hash.lluints[3] < target) {
        [self handleResult:&hash withNonce:nonce forJob:job.jobId];
      }
      worktime = (useconds_t)(endtime.tv_sec - starttime.tv_sec) * 1000000 + (useconds_t)(endtime.tv_usec - starttime.tv_usec);
      {
        uint32_t cnt = MIN((uint32_t)atomic_fetch_add(&ratecount, 1), (uint32_t)10);
        double prevrate = atomic_load(&hashrate);
        atomic_store(&hashrate, ((((double)1000000 * limit) / (double)worktime) + (prevrate * (double)cnt)) / (double)(cnt + 1));
      }
      if (limit < 1) {
        sleeptime = (useconds_t)((double)worktime * (1 - limit));
        usleep(sleeptime);
      }
    }
  }
  free(hashbuf);
}

- (double)hashRate {
  return atomic_load(&hashrate);
}

- (uint32_t)nonce {
  __strong MoneroBackend *backend = [self backend];
  if (!backend) return 0;
  return [backend nextNonceBlock:1];
}

- (double)resourceLimit {
  __strong MoneroBackend *backend = [self backend];
  if (!backend) return 0;
  return [backend cpuLimit];
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

