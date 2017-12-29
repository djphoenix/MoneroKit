//
//  NSData+hex.m
//  MoneroMiner
//
//  Created by Yury Popov on 21.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "NSData+hex.h"

NSData *_mm_dataFromHexString(NSString *hex) {
  if ((hex.length % 2) != 0) return nil;
  NSMutableData *data = [[NSMutableData alloc] initWithLength:hex.length / 2];
  unsigned char *dbytes = [data mutableBytes];
  char b[3] = {0,0,0}, *e;
  for (size_t i = 0; i < hex.length / 2; i++) {
    b[0] = (char)[hex characterAtIndex:i*2];
    b[1] = (char)[hex characterAtIndex:i*2+1];
    dbytes[i] = (unsigned char)strtoul(b, &e, 16);
    if (e != &b[2]) return nil;
  }
  return [[NSData alloc] initWithData:data];
}

NSString *_mm_hexStringFromData(NSData *data) {
  const unsigned char *dbytes = [data bytes];
  NSMutableString *hexStr = [NSMutableString stringWithCapacity:[data length]*2];
  for (size_t i = 0; i < [data length]; i++) {
    [hexStr appendFormat:@"%02x", dbytes[i]];
  }
  return [NSString stringWithString: hexStr];
}
