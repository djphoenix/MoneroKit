//
//  MoneroBackend.m
//  MoneroKit
//
//  Created by Yury Popov on 10.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroBackend_private.h"
#import "MoneroBackendCPUThread.h"
#import "MoneroBackendMetalThread.h"

#import <stdatomic.h>

@implementation MoneroBackend

- (instancetype)init {
  if (self = [super init]) {
    _cpuLimit = 1;
    _metalLimit = 1;
    _delegateQueue = dispatch_get_main_queue();
    
    NSMutableArray *arr = [NSMutableArray new];

    NSUInteger threads = [[NSProcessInfo processInfo] activeProcessorCount];
    for (NSUInteger i = 0; i < threads; i++) {
      MoneroBackendCPUThread *th = [[MoneroBackendCPUThread alloc] init];
      [th setBackend:self];
      [th setName:[NSString stringWithFormat:@"MoneroCPUBackend %@/%@",@(i),@(threads)]];
      [th setQualityOfService:NSQualityOfServiceBackground];
      [th start];
      [arr addObject:th];
    }
    
#if TARGET_OS_OSX
    NSArray *metalDevices = MTLCopyAllDevices();
#else
    NSArray *metalDevices = [NSArray arrayWithObjects:MTLCreateSystemDefaultDevice(), nil];
#endif
    for (id<MTLDevice> device in metalDevices) {
      MoneroBackendMetalThread *th = [[MoneroBackendMetalThread alloc] init];
      [th setBackend:self];
      [th setDevice:device];
      [th setName:[NSString stringWithFormat:@"MoneroMetalBackend %@", [device name]]];
      [th setQualityOfService:NSQualityOfServiceBackground];
      [th start];
      [arr addObject:th];
    }
    
    self.threadPool = arr;
  }
  return self;
}

- (void)dealloc {
  for (NSThread *th in _threadPool) {
    [th cancel];
  }
}

- (void)setCPULimit:(double)cpuLimit {
  _cpuLimit = MIN(1, MAX(0, cpuLimit));
}

- (void)setMetalLimit:(double)metalLimit {
  _metalLimit = MIN(1, MAX(0, metalLimit));
}

- (void)setCurrentJob:(MoneroBackendJob *)job {
  uint32_t nonce = arc4random();
  if (job.nicehash) nonce = (nonce & 0x00FFFFFF) | (job.nonce & 0xFF000000);
  atomic_store(&self->_nonce, nonce);
  _currentJob = job;
}

- (double)hashRate {
  double rate = 0;
  for (id th in _threadPool) {
    rate += [th hashRate];
  }
  return rate;
}

- (void)handleResult:(const struct MoneroHash*)hash withNonce:(uint32_t)nonce forJob:(NSString*)jobId {
  if (![jobId isEqualToString:self.currentJob.jobId]) return;
  id<MoneroBackendDelegate> delegate = [self delegate];
  dispatch_async(self.delegateQueue, ^{
    [delegate foundResult:hash withNonce:nonce forJobId:jobId];
  });
}

- (uint32_t)nextNonceBlock:(uint32_t)count {
  return atomic_fetch_add(&self->_nonce, count);
}

@end
