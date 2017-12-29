//
//  MoneroBackendMetalThread.h
//  MoneroMiner
//
//  Created by Yury Popov on 23.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

@import Foundation;
@import Metal;

@class MoneroBackend;

@interface MoneroBackendMetalThread : NSThread
@property (atomic, weak) MoneroBackend *backend;
@property (nonatomic, readonly) double hashRate;
@property (atomic, strong) id<MTLDevice> device;
@end
