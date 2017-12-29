//
//  NSData+hex.h
//  MoneroMiner
//
//  Created by Yury Popov on 21.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

@import Foundation;

NSData *_mm_dataFromHexString(NSString *hex);
NSString *_mm_hexStringFromData(NSData *data);
