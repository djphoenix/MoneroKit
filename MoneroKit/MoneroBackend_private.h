//
//  MoneroBackend_private.h
//  MoneroMiner
//
//  Created by Yury Popov on 21.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroBackend.h"

@interface MoneroBackend ()
@property (atomic) NSArray<NSThread*> *threadPool;
@property (atomic) _Atomic(uint32_t) nonce;
- (void)handleResult:(const struct MoneroHash*)hash withNonce:(uint32_t)nonce forJob:(NSString*)jobId;
- (uint32_t)nextNonceBlock:(uint32_t)count;
@end

