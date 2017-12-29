//
//  MoneroBackend.h
//  MoneroMiner
//
//  Created by Yury Popov on 10.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

@import Foundation;

struct MoneroHash {
  union {
    uint8_t bytes[32];
    uint32_t uints[8];
    uint64_t lluints[4];
  } __attribute((packed));
};

@interface MoneroBackendJob: NSObject
@property (nonatomic, copy) NSString *jobId;
@property (nonatomic, copy) NSData *blob;
@property (nonatomic) uint64_t target;
@property (nonatomic) BOOL nicehash;

@property (nonatomic, readonly) uint64_t versionMajor;
@property (nonatomic, readonly) uint64_t versionMinor;
@property (nonatomic, readonly) uint64_t timestamp;
@property (nonatomic, readonly) struct MoneroHash prevBlockHash;
@property (nonatomic, readonly) uint32_t nonce;
@property (nonatomic, readonly) ptrdiff_t nonceOffset;
@property (nonatomic, readonly) struct MoneroHash merkleRootHash;
@property (nonatomic, readonly) uint64_t transactionsCount;

@property (nonatomic, readonly) uint64_t difficulty;
@end

@protocol MoneroBackendDelegate
- (void)foundResult:(const struct MoneroHash*)result withNonce:(uint32_t)nonce forJobId:(NSString*)job;
@end

@interface MoneroBackend: NSObject
- (instancetype)init;
@property (nonatomic, readwrite, setter=setCPULimit:) double cpuLimit;
@property (nonatomic, readwrite) double metalLimit;
@property (nonatomic, readwrite) MoneroBackendJob *currentJob;
@property (nonatomic, readwrite) dispatch_queue_t delegateQueue;
@property (nonatomic, weak, readwrite) id<MoneroBackendDelegate> delegate;
@property (nonatomic, readonly) double hashRate;
@end
