//
//  MoneroMiner.m
//  MoneroKit
//
//  Created by Yury Popov on 08.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroKit.h"
#import "MoneroPoolConnection.h"
#import "MoneroBackend.h"

@interface MoneroNetworkLoopThread: NSThread
@property (nonatomic, readonly, nonnull) NSRunLoop *runLoop;
@end

@implementation MoneroNetworkLoopThread {
  NSRunLoop *_runLoop;
}
- (void)main {
  _runLoop = [NSRunLoop currentRunLoop];
  while (![self isCancelled]) {
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0.5];
    [_runLoop runUntilDate:date];
    [NSThread sleepUntilDate:date];
  }
}
- (NSRunLoop *)runLoop {
  while (!_runLoop) [NSThread sleepForTimeInterval:0.01];
  return _runLoop;
}
@end

@interface MoneroMiner () <MoneroPoolConnectionDelegate, MoneroBackendDelegate>
@property (atomic, nonnull) NSMutableArray<MoneroPoolConnection*> *connections;
@property (atomic, nonnull) MoneroBackend* backend;
@property (atomic, nonnull) MoneroNetworkLoopThread *networkThread;
@property (atomic, nonnull) NSMutableDictionary<NSString*, MoneroBackendJob*> *jobs;
@property (atomic, nonnull) NSMutableDictionary<NSString*, NSNumber*> *scores;
@property (atomic, nullable) NSString *currentWorker;
@property (atomic, nullable) NSDate *currentWorkerStart;
@property (atomic, nonnull) NSTimer *balanceTimer;
@property (atomic, nonnull) dispatch_queue_t bg_queue;
@property (atomic) BOOL reconnect;
@end

@implementation MoneroMiner

+ (NSString *)baseAddress:(NSString *)walletAddress {
  static NSString *const chars = @"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  NSCharacterSet *base58Chars = [NSCharacterSet characterSetWithCharactersInString:chars];
  NSCharacterSet *nonBase58Chars = [base58Chars invertedSet];
  return [[walletAddress componentsSeparatedByCharactersInSet:nonBase58Chars] firstObject];
}

- (instancetype)init {
  if (self = [super init]) {
    self.networkThread = [MoneroNetworkLoopThread new];
    self.networkThread.qualityOfService = NSQualityOfServiceBackground;
    [self.networkThread start];
    
    self.bg_queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
    self.connections = [NSMutableArray new];
    self.jobs = [NSMutableDictionary new];
    self.scores = [NSMutableDictionary new];

    self.backend = [MoneroBackend new];
    self.backend.delegateQueue = self.bg_queue;
    [self.backend setDelegate:self];
    
    self.reconnect = false;
    self.cpuLimit = 1;
    self.metalLimit = 1;
  }
  return self;
}

- (void)dealloc {
  [self.networkThread cancel];
}

- (double)cpuLimit {
  return [self.backend cpuLimit];
}

- (double)metalLimit {
  return [self.backend metalLimit];
}

- (void)setWorkers:(NSArray<MoneroWorker *> *)workers {
  _workers = [workers sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"weight" ascending:NO]]];
}

- (void)setCPULimit:(double)cpuLimit {
  [self.backend setCPULimit:cpuLimit];
}

- (void)setMetalLimit:(double)metalLimit {
  [self.backend setMetalLimit:metalLimit];
}

- (void)startMining {
  self.reconnect = true;
  for (MoneroPoolConnection *conn in self.connections) {
    [conn close];
  }
  [self.connections removeAllObjects];
  for (MoneroWorker *worker in self.workers) {
    MoneroPoolConnection *conn = [MoneroPoolConnection connectionWithHost:worker.poolHost port:worker.poolPort ssl:worker.poolSecure walletAddress:worker.walletAddress password:worker.password];
    [conn setRunLoop:self.networkThread.runLoop];
    [conn setDelegate:self];
    [conn setIdentifier:worker.identifier];
    [self.connections addObject:conn];
    [conn connect];
  }
  self.balanceTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(balanceJobs) userInfo:nil repeats:YES];
  [self.networkThread.runLoop addTimer:self.balanceTimer forMode:NSRunLoopCommonModes];
}

- (void)stopMining {
  [self.balanceTimer invalidate];
  self.reconnect = false;
  for (MoneroPoolConnection *conn in self.connections) {
    [conn close];
  }
  [self.connections removeAllObjects];
  [self.jobs removeAllObjects];
  [self balanceJobs];
}

- (BOOL)active {
  return self.reconnect && self.connections.count > 0;
}

- (void)connection:(MoneroPoolConnection *)connection receivedCommand:(NSString *)command withOptions:(NSDictionary<NSString *,id> *)options callback:(MoneroPoolConnectionCallback)callback {
  NSLog(@"%@ %@", command, options);
  callback(nil, nil);
}

- (void)connection:(MoneroPoolConnection *)connection error:(NSError *)error {
  id<MoneroMinerDelegate> delegate = [self delegate];
  [delegate miningError:error stopped:NO];
  [self.jobs removeObjectForKey:connection.identifier];
  [self balanceJobs];
  __weak __typeof__(self) wself = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), self.bg_queue, ^{
    __strong __typeof__(wself) self = wself;
    if (self && self.reconnect) [connection connect];
  });
}

- (void)connection:(MoneroPoolConnection *)connection receivedNewJob:(MoneroBackendJob *)job {
  id<MoneroMinerDelegate> delegate = [self delegate];
  MoneroBackendJob *oldJob = [self.jobs objectForKey:connection.identifier];
  MoneroWorker *worker = [[self.workers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", connection.identifier]] firstObject];
  if ([worker nicehash]) job.nicehash = YES;
  if (oldJob) {
    if ([oldJob.jobId isEqualToString:job.jobId]) {
      return;
    }
    if (oldJob.difficulty != job.difficulty) {
      [delegate difficultyChanged:(NSUInteger)job.difficulty forWorker:connection.identifier];
    }
    if ([oldJob.blob isEqualToData:job.blob]) {
      oldJob.jobId = job.jobId;
      oldJob.target = job.target;
      return;
    }
    if (memcmp(oldJob.prevBlockHash.bytes, job.prevBlockHash.bytes, sizeof(job.prevBlockHash.bytes)) != 0) {
      [delegate blockFoundForWorker:connection.identifier];
    }
  } else {
    [delegate difficultyChanged:(NSUInteger)job.difficulty forWorker:connection.identifier];
  }
  [self.jobs setObject:job forKey:connection.identifier];
  [self balanceJobs];
}

- (void)balanceJobs {
  MoneroBackendJob *currentJob = [self.backend currentJob];
  if (_currentWorkerStart != nil && (-[_currentWorkerStart timeIntervalSinceNow] < 10)) {
    MoneroBackendJob *job = [self.jobs objectForKey:_currentWorker];
    if ([job.jobId isEqualToString:currentJob.jobId]) return;
    [self.backend setCurrentJob:job];
    return;
  }

  double totalWeight = 0;
  double totalScore = 0 - [_currentWorkerStart timeIntervalSinceNow];
  
  for (MoneroWorker *w in _workers) {
    totalWeight += w.weight;
    totalScore += [[_scores objectForKey:w.identifier] doubleValue];
  }
  
  if (totalScore == 0 || totalWeight == 0) {
    [self pickJobForWorkers:_workers];
    return;
  }
  
  NSMutableDictionary *balanceWeights = [NSMutableDictionary new];

  for (MoneroWorker *w in _workers) {
    double dw = w.weight / totalWeight;
    double ws = [[_scores objectForKey:w.identifier] doubleValue];
    if ([_currentWorker isEqualToString:w.identifier]) ws -= [_currentWorkerStart timeIntervalSinceNow];
    double cw = ws / totalScore;
    double bw = MIN(dw / cw, (double)1);
    [balanceWeights setObject:@(bw) forKey:w.identifier];
  }
  
  [self pickJobForWorkers:[_workers sortedArrayUsingComparator:^NSComparisonResult(MoneroWorker *w1, MoneroWorker *w2) {
    NSNumber *bw1 = [balanceWeights objectForKey:w1.identifier];
    NSNumber *bw2 = [balanceWeights objectForKey:w2.identifier];
    return [bw2 compare:bw1];
  }]];
}

- (void)pickJobForWorkers:(NSArray<MoneroWorker*>*)workers {
  MoneroBackendJob *currentJob = [self.backend currentJob];

  for (MoneroWorker *w in workers) {
    MoneroBackendJob *job = [_jobs objectForKey:w.identifier];
    if (job != nil) {
      if ([job.jobId isEqualToString:currentJob.jobId]) return;
      if (![w.identifier isEqualToString:_currentWorker]) {
        if (_currentWorkerStart != nil && _currentWorker != nil) {
          [_scores setObject:@([_scores objectForKey:_currentWorker].doubleValue - [_currentWorkerStart timeIntervalSinceNow]) forKey:_currentWorker];
        }
        _currentWorker = w.identifier;
        _currentWorkerStart = [NSDate new];
      }
      [self.backend setCurrentJob:job];
      return;
    }
  }
  if (_currentWorkerStart != nil && _currentWorker != nil) {
    [_scores setObject:@([_scores objectForKey:_currentWorker].doubleValue - [_currentWorkerStart timeIntervalSinceNow]) forKey:_currentWorker];
  }
  _currentWorker = nil;
  _currentWorkerStart = nil;
  [self.backend setCurrentJob:nil];
}

- (MoneroPoolConnection*)connectionWithId:(NSString*)connId {
  return [[self.connections filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", connId]] firstObject];
}

- (MoneroPoolConnection*)connectionForJob:(NSString*)jobId {
  for (NSString *connId in self.jobs) {
    MoneroBackendJob *job = self.jobs[connId];
    if ([job.jobId isEqualToString:jobId]) {
      return [self connectionWithId:connId];
    }
  }
  return nil;
}

- (void)foundResult:(const struct MoneroHash*)result withNonce:(uint32_t)nonce forJobId:(NSString *)jobId {
  MoneroPoolConnection *conn = [self connectionForJob:jobId];
  if (conn == nil) return;
  NSUInteger resDiff = (NSUInteger)(0xFFFFFFFFFFFFFFFFLLU / result->lluints[3]);
  __weak __typeof__(self) wself = self;
  NSString *cid = conn.identifier;
  [conn submitShare:result withNonce:nonce forJobId:jobId callback:^(NSError *_Nullable error){
    __strong __typeof__(wself) self = wself;
    if (self) {
      dispatch_async(self.bg_queue, ^{
        __strong __typeof__(wself) self = wself;
        if (self) {
          id<MoneroMinerDelegate> delegate = [self delegate];
          if (error == nil) {
            [delegate acceptedResult:resDiff forWorker:cid];
          } else {
            [delegate miningError:error stopped:NO];
          }
        }
      });
    }
  }];
}

- (double)hashRate {
  return [self.backend hashRate];
}

@end
