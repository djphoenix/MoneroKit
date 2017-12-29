//
//  MoneroPoolConnection.h
//  MoneroKit
//
//  Created by Yury Popov on 08.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroKit.h"
#import "MoneroBackend.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^MoneroPoolConnectionCallback)(NSError *_Nullable error, NSDictionary<NSString*,id> *_Nullable result);
typedef void(^MoneroPoolResultCallback)(NSError *_Nullable error);

@class MoneroPoolConnection;

@protocol MoneroPoolConnectionDelegate
- (void)connection:(MoneroPoolConnection*)connection receivedCommand:(NSString*)command withOptions:(NSDictionary<NSString*,id>*)options callback:(MoneroPoolConnectionCallback)callback;
- (void)connection:(MoneroPoolConnection*)connection receivedNewJob:(MoneroBackendJob*)job;
- (void)connection:(MoneroPoolConnection*)connection error:(NSError*)error;
@end

@interface MoneroPoolConnection : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithHost:(NSString*)host port:(NSInteger)port ssl:(BOOL)ssl walletAddress:(NSString*)walletAddress password:(NSString*)password;
+ (instancetype)connectionWithHost:(NSString*)host port:(NSInteger)port ssl:(BOOL)ssl walletAddress:(NSString*)walletAddress password:(NSString*)password;
- (void)connect;
- (void)close;
@property (atomic, copy, nullable) NSString *identifier;
@property (atomic, strong) NSRunLoop *runLoop;
@property (weak, nonatomic, nullable) id<MoneroPoolConnectionDelegate> delegate;
- (void)sendCommand:(NSString*)command withOptions:(NSDictionary<NSString*,id>*)options callback:(MoneroPoolConnectionCallback)callback;
- (void)submitShare:(const struct MoneroHash*)hash withNonce:(uint32_t)nonce forJobId:(NSString*)jobId callback:(MoneroPoolResultCallback)callback;
@end

NS_ASSUME_NONNULL_END
