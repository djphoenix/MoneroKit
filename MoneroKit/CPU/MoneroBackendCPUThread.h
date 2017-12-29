//
//  MoneroBackendCPUThread.h
//  MoneroMiner
//
//  Created by Yury Popov on 21.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

@import Foundation;

@class MoneroBackend;

@interface MoneroBackendCPUThread: NSThread
@property (atomic, weak) MoneroBackend *backend;
@property (nonatomic, readonly) double hashRate;
@end
