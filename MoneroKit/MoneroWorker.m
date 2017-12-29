//
//  MoneroWorker.m
//  MoneroMiner
//
//  Created by Yury Popov on 27.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroKit.h"

@implementation MoneroWorker

+ (instancetype)workerWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString *)wallet {
  return [self workerWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:NO walletAddress:wallet password:@"x" weight:1];
}

+ (instancetype)workerWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString *)wallet password:(NSString *)password {
  return [self workerWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:NO walletAddress:wallet password:password weight:1];
}

+ (instancetype)workerWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString *)wallet password:(NSString *)password weight:(double)weight {
  return [self workerWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:NO walletAddress:wallet password:password weight:weight];
}

+ (instancetype)workerWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString *)wallet {
  return [self workerWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:nicehash walletAddress:wallet password:@"x" weight:1];
}

+ (instancetype)workerWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString *)wallet password:(NSString *)password {
  return [self workerWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:nicehash walletAddress:wallet password:password weight:1];
}

+ (instancetype)workerWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString *)wallet password:(NSString *)password weight:(double)weight {
  return [[self alloc] initWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:nicehash walletAddress:wallet password:password weight:weight];
}

- (instancetype)initWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString *)wallet {
  return [self initWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:NO walletAddress:wallet password:@"x" weight:1];
}

- (instancetype)initWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString *)wallet password:(NSString *)password {
  return [self initWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:NO walletAddress:wallet password:password weight:1];
}

- (instancetype)initWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString *)wallet password:(NSString *)password weight:(double)weight {
  return [self initWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:NO walletAddress:wallet password:password weight:1];
}

- (instancetype)initWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString *)wallet {
  return [self initWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:nicehash walletAddress:wallet password:@"x" weight:1];
}

- (instancetype)initWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString *)wallet password:(NSString *)password {
  return [self initWithIdentifier:identifier poolHost:host port:port secure:secure nicehash:nicehash walletAddress:wallet password:password weight:1];
}

- (instancetype)initWithIdentifier:(NSString *)identifier poolHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString *)wallet password:(NSString *)password weight:(double)weight {
  if (self = [super init]) {
    _identifier = [identifier copy];
    _poolHost = [host copy];
    _poolPort = port;
    _poolSecure = secure;
    _nicehash = nicehash;
    _walletAddress = [wallet copy];
    _password = [password copy];
    _weight = weight;
  }
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%@ stratum+%@://[%@:%@]@%@:%@ nicehash:%@ weight:%@>", NSStringFromClass([self class]), _identifier, _poolSecure ? @"ssl" : @"tcp", _walletAddress, _password, _poolHost, @(_poolPort), _nicehash ? @"YES" : @"NO", @(_weight)];
}

@end
