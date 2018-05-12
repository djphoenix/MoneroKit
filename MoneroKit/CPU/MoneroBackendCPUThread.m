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

