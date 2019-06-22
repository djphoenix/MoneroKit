//
//  MoneroBackendJob.m
//  MoneroKit
//
//  Created by Yury Popov on 10.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

#import "MoneroBackend.h"
#import "NSData+hex.h"

@implementation MoneroBackendJob {
  uint64_t _versionMajor;
  uint64_t _versionMinor;
  uint64_t _timestamp;
  struct MoneroHash _prevBlockHash;
  ptrdiff_t _nonceOffset;
  uint32_t _nonce;
  struct MoneroHash _merkleRootHash;
  uint64_t _transactionsCount;
  uint64_t _height;
}

- (void)setBlob:(NSData *)blob {
  if ([self parseBlob:blob]) {
    _blob = blob;
  }
}

static inline uint64_t read_varint(const uint8_t **buf, const uint8_t *end) {
  const uint8_t *p = *buf;
  uint8_t len = 0, tmp;
  uint64_t ret = 0;
  while (p < end) {
    tmp = *(p++);
    ret |= (uint64_t)((tmp & 0x7F) << ((len++) * 7));
    if ((tmp & 0x80) == 0) break;
  }
  *buf = p;
  return ret;
}

- (BOOL)parseBlob:(NSData *)blob {
  const uint8_t *s = blob.bytes, *b = s, *e = b + blob.length;
  _versionMajor = read_varint(&b, e);
  _versionMinor = read_varint(&b, e);
  _timestamp = read_varint(&b, e);
  if (b + sizeof(_prevBlockHash) >= e) return NO;
  memcpy(&_prevBlockHash, b, sizeof(_prevBlockHash)); b += sizeof(_prevBlockHash);
  if (b + sizeof(_nonce) >= e) return NO;
  _nonceOffset = b - s;
  memcpy(&_nonce, b, sizeof(_nonce)); b += sizeof(_nonce);
  if (b + sizeof(_merkleRootHash) >= e) return NO;
  memcpy(&_merkleRootHash, b, sizeof(_merkleRootHash)); b += sizeof(_merkleRootHash);
  _transactionsCount = read_varint(&b, e);
  if (b != e || (*(b-1)&0x80) != 0) return NO;
  return YES;
}

- (uint64_t)difficulty {
  return 0xFFFFFFFFFFFFFFFFLLU / self.target;
}

- (NSString *)description {
  NSString *prevHex = _mm_hexStringFromData([NSData dataWithBytes:_prevBlockHash.bytes length:sizeof(_prevBlockHash)]);
  NSString *rootHex = _mm_hexStringFromData([NSData dataWithBytes:_merkleRootHash.bytes length:sizeof(_merkleRootHash)]);
  NSString *blobDesc = [NSString stringWithFormat:@"<v%@.%@ stamp:%@ prev:<%@> nonce:<%08x> root:<%@> tx:%@>", @(_versionMajor), @(_versionMinor), @(_timestamp), prevHex, _nonce, rootHex, @(_transactionsCount)];
  return [NSString stringWithFormat:@"<ID:<%@> DIFF:%@ BLOB:%@>", self.jobId, @(self.difficulty), blobDesc];
}

@end
