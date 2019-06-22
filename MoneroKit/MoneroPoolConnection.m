//
//  MoneroPoolConnection.m
//  MoneroKit
//
//  Created by Yury Popov on 08.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroPoolConnection.h"
#import "MoneroBackend.h"
#import "NSData+hex.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>

static const char agentString[] = "MoneroKit/1.0";

@interface MoneroPoolConnection () <NSStreamDelegate>
@property (atomic, strong) NSString *host;
@property (atomic, strong) NSString *user;
@property (atomic, strong) NSString *password;
@property (atomic, strong) NSInputStream *input;
@property (atomic, strong) NSOutputStream *output;
@property (atomic, strong) NSMutableData *inBuffer;
@property (atomic, strong) NSMutableData *outBuffer;
@property (atomic, strong) NSString *workerId;
@property (atomic, strong) NSMutableDictionary<NSNumber*,MoneroPoolConnectionCallback> *callbacks;
@property (atomic) uint16_t port;
@property (atomic) uint32_t seq;
@property (atomic) BOOL ssl;
@property (atomic) NSTimer *pingTimer;
@end

@implementation MoneroPoolConnection

+ (instancetype)connectionWithHost:(NSString*)host port:(NSInteger)port ssl:(BOOL)ssl walletAddress:(NSString*)walletAddress password:(NSString*)password {
  return [[self alloc] initWithHost:host port:port ssl:ssl walletAddress:walletAddress password:password];
}

- (instancetype)initWithHost:(NSString*)host port:(NSInteger)port ssl:(BOOL)ssl walletAddress:(NSString*)walletAddress password:(NSString*)password {
  if (self = [super init]) {
    self.runLoop = [NSRunLoop mainRunLoop];
    self.host = host;
    self.user = walletAddress;
    self.password = password;
    self.port = (uint16_t)port;
    self.ssl = ssl;
    self.outBuffer = [NSMutableData new];
    self.inBuffer = [NSMutableData new];
    self.workerId = nil;
    self.callbacks = [NSMutableDictionary new];
  }
  return self;
}

- (void)connect {
  NSInputStream *ins; NSOutputStream *outs;
  [NSStream getStreamsToHostWithName:_host port:_port inputStream:&ins outputStream:&outs];

  [ins setProperty:NSStreamNetworkServiceTypeBackground forKey:NSStreamNetworkServiceType];
  [outs setProperty:NSStreamNetworkServiceTypeBackground forKey:NSStreamNetworkServiceType];
  
  if (self.ssl) {
    NSDictionary *sets = @{
                           (__bridge NSString*)kCFStreamSSLValidatesCertificateChain: @NO
                           };
    [ins setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
    [outs setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
    [ins setProperty:sets forKey:(__bridge NSString*)kCFStreamPropertySSLSettings];
    [outs setProperty:sets forKey:(__bridge NSString*)kCFStreamPropertySSLSettings];
  }
  
  [ins setDelegate:self];
  [outs setDelegate:self];
  [ins scheduleInRunLoop:_runLoop forMode:NSRunLoopCommonModes];
  [outs scheduleInRunLoop:_runLoop forMode:NSRunLoopCommonModes];
  [(self.input = ins) open];
  [(self.output = outs) open];

  [self.outBuffer setLength:0];
  [self.inBuffer setLength:0];
  [self.callbacks removeAllObjects];
  self.seq = 0;
  __weak __typeof__(self) wself = self;
  [self sendCommand:@"login" withOptions:@{@"login":_user, @"pass":_password, @"agent":@(agentString)} callback:^(NSError *error, NSDictionary<NSString*,id>* result) {
    __strong __typeof__(wself) self = wself;
    if (!self) return;
    self.workerId = [[result objectForKey:@"id"] copy];
    [self handleJob:[result objectForKey:@"job"]];
    [self heartbeat];
  }];
}

- (void)heartbeat {
  [self.pingTimer invalidate];
  self.pingTimer = [NSTimer timerWithTimeInterval:30 target:self selector:@selector(sendHeartbeat) userInfo:nil repeats:NO];
  [_runLoop addTimer:self.pingTimer forMode:NSRunLoopCommonModes];
}

- (void)sendHeartbeat {
  if (!self.workerId) return;
  __weak __typeof__(self) wself = self;
  [self sendCommand:@"getjob" withOptions:@{@"id": self.workerId} callback:^(NSError *error, NSDictionary<NSString*,id>* result) {
    __strong __typeof__(wself) self = wself;
    if (!self) return;
    [self handleJob:result];
  }];
  [self heartbeat];
}

- (void)close {
  [self.pingTimer invalidate];
  self.pingTimer = nil;
  [self.input removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
  [self.output removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
  [self.input close];
  [self.output close];
  self.input = nil;
  self.output = nil;
  [self.outBuffer setLength:0];
  [self.inBuffer setLength:0];
  [self.callbacks removeAllObjects];
}

inline static uint64_t t32_to_t64(uint32_t t) { return 0xFFFFFFFFFFFFFFFFULL / (0xFFFFFFFFULL / ((uint64_t)t)); }

- (void)handleJob:(NSDictionary*)dict {
  id<MoneroPoolConnectionDelegate> delegate = [self delegate];
  if (!delegate) return;
  NSString *jid = [dict objectForKey:@"job_id"];
  NSString *blobS = [dict objectForKey:@"blob"];
  NSString *targetS = [dict objectForKey:@"target"];
  if (![jid isKindOfClass:[NSString class]] ||
      ![blobS isKindOfClass:[NSString class]] ||
      ![targetS isKindOfClass:[NSString class]]) return;

  uint64_t height = 0;
  if ([[dict objectForKey:@"height"] isKindOfClass:[NSNumber class]])
    height = [(NSNumber*)[dict objectForKey:@"height"] unsignedLongLongValue];

  NSData *blob = _mm_dataFromHexString(blobS);
  NSData *target = _mm_dataFromHexString(targetS);

  MoneroBackendJob *job = [MoneroBackendJob new];
  [job setJobId:jid];
  [job setBlob:blob];
  [job setHeight:height];
  if ([target length] <= 4) {
    uint32_t tmp = 0;
    [target getBytes:&tmp length:sizeof(tmp)];
    [job setTarget:t32_to_t64(tmp)];
  } else if ([target length] <= 8) {
    uint64_t tmp = 0;
    [target getBytes:&tmp length:sizeof(tmp)];
    [job setTarget:tmp];
  } else {
    return;
  }
  [delegate connection:self receivedNewJob:job];
}

- (void)sendCommand:(NSString *)command withOptions:(NSDictionary<NSString*,id>*)options callback:(MoneroPoolConnectionCallback)callback {
  NSDictionary *cmd = @{
                        @"method": command,
                        @"params": options,
                        @"id": @(++_seq)
                        };
  if (callback) [self.callbacks setObject:callback forKey:@(_seq)];
  [self writeJSON:cmd];
}

- (void)submitShare:(const struct MoneroHash*)hash withNonce:(uint32_t)nonce forJobId:(NSString*)jobId callback:(nonnull MoneroPoolResultCallback)callback {
  if (!self.workerId) {
    callback([NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUserAuthenticationRequired userInfo:nil]);
    return;
  }
  NSString *hashHex = _mm_hexStringFromData([NSData dataWithBytes:hash->bytes length:sizeof(hash->bytes)]);
  NSString *nonceHex = _mm_hexStringFromData([NSData dataWithBytes:&nonce length:sizeof(nonce)]);
  [self sendCommand:@"submit"
        withOptions:@{
                      @"id": self.workerId,
                      @"job_id": jobId,
                      @"nonce": nonceHex,
                      @"result": hashHex
                      }
           callback:^(NSError * _Nullable error, NSDictionary<NSString *,id> * _Nullable result) {
             if (error) {
               callback(error);
             } else if ([[result objectForKey:@"status"] isEqual:@"OK"]) {
               callback(nil);
             } else {
               callback([NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:result]);
             }
             [self heartbeat];
           }
   ];
}

- (void)writeJSON:(NSDictionary<NSString*,id>*)json {
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
  if (!data || error) {
    [self handleError:error];
    return;
  }
  [self.outBuffer appendBytes:data.bytes length:data.length];
  [self.outBuffer appendBytes:(char[]){'\n'} length:1];
  if (self.output && self.output.streamStatus == NSStreamStatusOpen && self.output.hasSpaceAvailable) {
    [self processOutputBuffer];
  }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
  if (aStream == self.input) [self handleInputEvent:eventCode];
  if (aStream == self.output) [self handleOutputEvent:eventCode];
}

- (void)handleInputEvent:(NSStreamEvent)event {
  switch (event) {
    case NSStreamEventOpenCompleted: {
      CFDataRef socketData = CFReadStreamCopyProperty((__bridge CFReadStreamRef)_input, kCFStreamPropertySocketNativeHandle);
      CFSocketNativeHandle socket;
      CFDataGetBytes(socketData, CFRangeMake(0, sizeof(CFSocketNativeHandle)), (UInt8 *)&socket);
      CFRelease(socketData);
      setsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, (int[]){1}, sizeof(int));
      setsockopt(socket, IPPROTO_TCP, TCP_KEEPCNT, (int[]){4}, sizeof(int));
      setsockopt(socket, IPPROTO_TCP, TCP_KEEPALIVE, (int[]){10}, sizeof(int));
      setsockopt(socket, IPPROTO_TCP, TCP_KEEPINTVL, (int[]){2}, sizeof(int));
      setsockopt(socket, IPPROTO_TCP, TCP_RXT_CONNDROPTIME, (int[]){5}, sizeof(int));
      setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, (int[]){1}, sizeof(int));
      break; }
    case NSStreamEventEndEncountered:
      [self handleError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil]];
      break;
    case NSStreamEventErrorOccurred:
      [self handleError:self.input.streamError];
      break;
    case NSStreamEventHasBytesAvailable: {
      NSMutableData *buf = [[NSMutableData alloc] initWithLength:4096];
      NSInteger len = 0;
      while ([self.input hasBytesAvailable] && (len = [self.input read:buf.mutableBytes maxLength:buf.length]) > 0) {
        [self.inBuffer appendBytes:buf.bytes length:(NSUInteger)len];
      }
      [self processInputBuffer];
      break; }
    default: break;
  }
}

- (void)processInputBuffer {
  while ([self.inBuffer length] > 0) {
    const char *s = [self.inBuffer bytes];
    const char *e = memchr(s, '\n', [self.inBuffer length]);
    if (e == 0) break;
    NSUInteger len = (NSUInteger)(e - s + 1);
    NSData *line = [self.inBuffer subdataWithRange:NSMakeRange(0, len)];
    [self.inBuffer setData:[self.inBuffer subdataWithRange:NSMakeRange(len, [self.inBuffer length] - len)]];
    id json = [NSJSONSerialization JSONObjectWithData:line options:NSJSONReadingAllowFragments error:nil];
    [self processJSONMessage:json];
  }
}

- (void)handleCommand:(NSString *)command withOptions:(NSDictionary<NSString*,id>*)options callback:(MoneroPoolConnectionCallback)callback {
  if ([command isEqualToString:@"job"]) {
    [self handleJob:options];
    callback(nil, @{@"status":@"OK"});
  } else {
    id<MoneroPoolConnectionDelegate> delegate = [self delegate];
    if (delegate) {
      [delegate connection:self receivedCommand:command withOptions:options callback:callback];
    } else {
      callback(nil, nil);
    }
  }
}

- (void)processJSONMessage:(NSDictionary<NSString*,id>*)json {
  NSNumber *seq = [json objectForKey:@"id"];
  NSString *method = [json objectForKey:@"method"];
  NSDictionary *params = [json objectForKey:@"params"];
  NSDictionary *result = [json objectForKey:@"result"];
  NSDictionary *error = [json objectForKey:@"error"];
  if ([method isKindOfClass:[NSString class]] && [params isKindOfClass:[NSDictionary class]]) {
    __weak __typeof__(self) wself = self;
    [self handleCommand:method withOptions:params callback:^(NSError *error, NSDictionary<NSString *,id> *result) {
      if (![seq isKindOfClass:[NSNumber class]]) return;
      __strong __typeof__(wself) self = wself;
      if (!self) return;
      if (result) {
        [self writeJSON:@{
                          @"id": seq,
                          @"result": result,
                          @"error": [NSNull null]
                          }];
      } else if (error) {
        NSLog(@"%@", error);
      }
    }];
  } else if ([seq isKindOfClass:[NSNumber class]] && [result isKindOfClass:[NSDictionary class]]) {
    MoneroPoolConnectionCallback cb = [self.callbacks objectForKey:seq];
    [self.callbacks removeObjectForKey:seq];
    if (cb) {
      cb(nil, result);
    } else {
      NSLog(@"%@", json);
    }
  } else if ([seq isKindOfClass:[NSNumber class]] && [error isKindOfClass:[NSDictionary class]]) {
    MoneroPoolConnectionCallback cb = [self.callbacks objectForKey:seq];
    [self.callbacks removeObjectForKey:seq];
    if (cb) {
      cb(
         [NSError errorWithDomain:@"MoneroKitErrorDomain"
                             code:[[error objectForKey:@"code"] integerValue]
                         userInfo:@{ NSLocalizedDescriptionKey: [error objectForKey:@"message"] }],
         nil
         );
    } else {
      NSLog(@"%@", json);
    }
  } else {
    NSLog(@"%@", json);
  }
}

- (void)processOutputBuffer {
  NSUInteger buflen = self.outBuffer.length;
  if (buflen == 0) return;
  NSInteger len = [self.output write:[self.outBuffer bytes] maxLength:buflen];
  if (len > 0) {
    [self.outBuffer setData:[self.outBuffer subdataWithRange:NSMakeRange((NSUInteger)len, MIN(buflen - (NSUInteger)len, (NSUInteger)0))]];
  }
}

- (void)handleOutputEvent:(NSStreamEvent)event {
  switch (event) {
    case NSStreamEventEndEncountered:
      [self handleError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil]];
      break;
    case NSStreamEventErrorOccurred:
      [self handleError:self.output.streamError];
      break;
    case NSStreamEventHasSpaceAvailable:
      [self processOutputBuffer];
      break;
    default: break;
  }
}

- (void)handleError:(NSError*)error {
  [self close];
  id<MoneroPoolConnectionDelegate> delegate = [self delegate];
  [delegate connection:self error:error];
}

@end
