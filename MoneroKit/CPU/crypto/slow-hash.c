// Copyright (c) 2014-2017, The Monero Project
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Parts of this file are originally copyright (c) 2012-2013 The Cryptonote developers

#include <stdlib.h>

#include "int-util.h"
#include "hash-ops.h"
#include "keccak.h"
#include "math.h"

#pragma mark - Global defines

enum {
  MEMORY          = 1 << 21,
  ITER            = 1 << 20,
  AES_BLOCK_SIZE  = 16,
  AES_KEYEXP_SIZE = 176,
  INIT_SIZE_BLK   = 8,
  INIT_SIZE_BYTE  = INIT_SIZE_BLK * AES_BLOCK_SIZE,
  TOTALBLOCKS     = MEMORY / AES_BLOCK_SIZE,
};

#define INLINE inline __attribute__((always_inline))

#define PACKED __attribute__((packed))
#define RDATA_ALIGN16 __attribute__ ((aligned(16)))
#define R128(x) ((REG128 *) (x))

#if defined(__x86_64__)
#pragma mark - X86-64

#include <emmintrin.h>
#include <wmmintrin.h>

typedef __m128i REG128;

#define state_index(x) ((((uint32_t)x[0]) & ((TOTALBLOCKS - 1) << 4)))

static const __m128i zero = {0};

#define xor128(a, b) _mm_xor_si128((a), (b))
#define mul128(a, b, hi, lo) __asm__ ("mulq %3\n\t" : "=d"(hi), "=a"(lo) : "%a" (a[0]), "%b" (b[0]) : "cc");
#define aesenc(a, k) _mm_aesenc_si128((a), (k))

static INLINE void aes_256_assist1(__m128i* t1, __m128i * t2) {
  __m128i t4;
  *t2 = _mm_shuffle_epi32(*t2, 0xff);
  t4 = _mm_slli_si128(*t1, 0x04);
  *t1 = _mm_xor_si128(*t1, t4);
  t4 = _mm_slli_si128(t4, 0x04);
  *t1 = _mm_xor_si128(*t1, t4);
  t4 = _mm_slli_si128(t4, 0x04);
  *t1 = _mm_xor_si128(*t1, t4);
  *t1 = _mm_xor_si128(*t1, *t2);
}
__attribute__((__target__("aes")))
static INLINE void aes_256_assist2(__m128i* t1, __m128i * t3) {
  __m128i t2, t4;
  t4 = _mm_aeskeygenassist_si128(*t1, 0x00);
  t2 = _mm_shuffle_epi32(t4, 0xaa);
  t4 = _mm_slli_si128(*t3, 0x04);
  *t3 = _mm_xor_si128(*t3, t4);
  t4 = _mm_slli_si128(t4, 0x04);
  *t3 = _mm_xor_si128(*t3, t4);
  t4 = _mm_slli_si128(t4, 0x04);
  *t3 = _mm_xor_si128(*t3, t4);
  *t3 = _mm_xor_si128(*t3, t2);
}

/**
 * @brief expands 'key' into a form it can be used for AES encryption.
 *
 * This is an SSE-optimized implementation of AES key schedule generation.  It
 * expands the key into multiple round keys, each of which is used in one round
 * of the AES encryption used to fill (and later, extract randomness from)
 * the large 2MB buffer.  Note that CryptoNight does not use a completely
 * standard AES encryption for its buffer expansion, so do not copy this
 * function outside of Monero without caution!  This version uses the hardware
 * AESKEYGENASSIST instruction to speed key generation, and thus requires
 * CPU AES support.
 * For more information about these functions, see page 19 of Intel's AES instructions
 * white paper:
 * http://www.intel.com/content/dam/www/public/us/en/documents/white-papers/aes-instructions-set-white-paper.pdf
 *
 * @param key the input 128 bit key
 * @param expandedKey An output buffer to hold the generated key schedule
 */
__attribute__((__target__("aes")))
static INLINE void aes_expand_key(const uint8_t *key, uint8_t *expandedKey)
{
  __m128i *ek = R128(expandedKey);
  __m128i t1, t2, t3;
  
  t1 = *R128(key);
  t3 = *R128(key + 16);
  
  ek[0] = t1;
  ek[1] = t3;
  
  t2 = _mm_aeskeygenassist_si128(t3, 0x01);
  aes_256_assist1(&t1, &t2);
  ek[2] = t1;
  aes_256_assist2(&t1, &t3);
  ek[3] = t3;
  
  t2 = _mm_aeskeygenassist_si128(t3, 0x02);
  aes_256_assist1(&t1, &t2);
  ek[4] = t1;
  aes_256_assist2(&t1, &t3);
  ek[5] = t3;
  
  t2 = _mm_aeskeygenassist_si128(t3, 0x04);
  aes_256_assist1(&t1, &t2);
  ek[6] = t1;
  aes_256_assist2(&t1, &t3);
  ek[7] = t3;
  
  t2 = _mm_aeskeygenassist_si128(t3, 0x08);
  aes_256_assist1(&t1, &t2);
  ek[8] = t1;
  aes_256_assist2(&t1, &t3);
  ek[9] = t3;
  
  t2 = _mm_aeskeygenassist_si128(t3, 0x10);
  aes_256_assist1(&t1, &t2);
  ek[10] = t1;
}

/**
 * @brief a "pseudo" round of AES (similar to but slightly different from normal AES encryption)
 *
 * To fill its 2MB scratch buffer, CryptoNight uses a nonstandard implementation
 * of AES encryption:  It applies 10 rounds of the basic AES encryption operation
 * to an input 128 bit chunk of data <in>.  Unlike normal AES, however, this is
 * all it does;  it does not perform the initial AddRoundKey step (this is done
 * in subsequent steps by aesenc_si128), and it does not use the simpler final round.
 * Hence, this is a "pseudo" round - though the function actually implements 10 rounds together.
 *
 * Note that unlike aesb_pseudo_round, this function works on multiple data chunks.
 *
 * @param in a pointer to nblocks * 128 bits of data to be encrypted
 * @param out a pointer to an nblocks * 128 bit buffer where the output will be stored
 * @param expandedKey the expanded AES key
 * @param nblocks the number of 128 blocks of data to be encrypted
 */
__attribute__((__target__("aes")))
static INLINE void aes_pseudo_round(const uint8_t *in, uint8_t *out,
                                    const uint8_t *expandedKey, int nblocks)
{
  __m128i *k = R128(expandedKey);
  __m128i d;
  int i;
  
  for(i = 0; i < nblocks; i++)
  {
    d = R128(in)[i];
    d = _mm_aesenc_si128(d, k[0]);
    d = _mm_aesenc_si128(d, k[1]);
    d = _mm_aesenc_si128(d, k[2]);
    d = _mm_aesenc_si128(d, k[3]);
    d = _mm_aesenc_si128(d, k[4]);
    d = _mm_aesenc_si128(d, k[5]);
    d = _mm_aesenc_si128(d, k[6]);
    d = _mm_aesenc_si128(d, k[7]);
    d = _mm_aesenc_si128(d, k[8]);
    d = _mm_aesenc_si128(d, k[9]);
    R128(out)[i] = d;
  }
}

/**
 * @brief aes_pseudo_round that loads data from *in and xors it with *xor first
 *
 * This function performs the same operations as aes_pseudo_round, but before
 * performing the encryption of each 128 bit block from <in>, it xors
 * it with the corresponding block from <xor>.
 *
 * @param in a pointer to nblocks * 128 bits of data to be encrypted
 * @param out a pointer to an nblocks * 128 bit buffer where the output will be stored
 * @param expandedKey the expanded AES key
 * @param xor a pointer to an nblocks * 128 bit buffer that is xored into in before encryption (in is left unmodified)
 * @param nblocks the number of 128 blocks of data to be encrypted
 */
__attribute__((__target__("aes")))
static INLINE void aes_pseudo_round_xor(const uint8_t *in, uint8_t *out,
                                        const uint8_t *expandedKey, const uint8_t *xor, int nblocks)
{
  __m128i *k = R128(expandedKey);
  __m128i *x = R128(xor);
  __m128i d;
  int i;
  
  for(i = 0; i < nblocks; i++)
  {
    d = R128(in)[i];
    d = _mm_xor_si128(d, *(x++));
    d = _mm_aesenc_si128(d, k[0]);
    d = _mm_aesenc_si128(d, k[1]);
    d = _mm_aesenc_si128(d, k[2]);
    d = _mm_aesenc_si128(d, k[3]);
    d = _mm_aesenc_si128(d, k[4]);
    d = _mm_aesenc_si128(d, k[5]);
    d = _mm_aesenc_si128(d, k[6]);
    d = _mm_aesenc_si128(d, k[7]);
    d = _mm_aesenc_si128(d, k[8]);
    d = _mm_aesenc_si128(d, k[9]);
    R128(out)[i] = d;
  }
}

#elif defined(__aarch64__) && defined(__ARM_FEATURE_CRYPTO)
#pragma mark - ARM64-NEON

#include <arm_neon.h>

typedef uint8x16_t REG128;

#define state_index(x) (((*((uint32_t*)&x)) & ((TOTALBLOCKS - 1) << 4)))

static const uint8x16_t zero = {0};
#define xor128(a, b) veorq_u8((a), (b))
#define mul128(a, b, hi, lo) do { \
__asm__("mul %0, %1, %2\n\t" : "=r"(lo) : "r"(*(uint64_t*)&(a)), "r"(*(uint64_t*)&(b)) ); \
__asm__("umulh %0, %1, %2\n\t" : "=r"(hi) : "r"(*(uint64_t*)&(a)), "r"(*(uint64_t*)&(b)) ); \
} while (0)
#define aesenc(a, k) veorq_u8(vaesmcq_u8(vaeseq_u8((a), zero)), k)

/* Note: this was based on a standard 256bit key schedule but
 * it's been shortened since Cryptonight doesn't use the full
 * key schedule. Don't try to use this for vanilla AES.
 */
static const int rcon[] = {
  0x01,0x01,0x01,0x01,
  0x0c0f0e0d,0x0c0f0e0d,0x0c0f0e0d,0x0c0f0e0d,  // rotate-n-splat
  0x1b,0x1b,0x1b,0x1b };

static __attribute__((noinline)) void aes_expand_key(const uint8_t *key, uint8_t *expandedKey) {
  __asm__(
          "  eor  v0.16b,v0.16b,v0.16b\n"
          "  ld1  {v3.16b},[%0],#16\n"
          "  ld1  {v1.4s,v2.4s},[%2],#32\n"
          "  ld1  {v4.16b},[%0]\n"
          "  mov  w2,#5\n"
          "  st1  {v3.4s},[%1],#16\n"
          "\n"
          "1:\n"
          "  tbl  v6.16b,{v4.16b},v2.16b\n"
          "  ext  v5.16b,v0.16b,v3.16b,#12\n"
          "  st1  {v4.4s},[%1],#16\n"
          "  aese  v6.16b,v0.16b\n"
          "  subs  w2,w2,#1\n"
          "\n"
          "  eor  v3.16b,v3.16b,v5.16b\n"
          "  ext  v5.16b,v0.16b,v5.16b,#12\n"
          "  eor  v3.16b,v3.16b,v5.16b\n"
          "  ext  v5.16b,v0.16b,v5.16b,#12\n"
          "  eor  v6.16b,v6.16b,v1.16b\n"
          "  eor  v3.16b,v3.16b,v5.16b\n"
          "  shl  v1.16b,v1.16b,#1\n"
          "  eor  v3.16b,v3.16b,v6.16b\n"
          "  st1  {v3.4s},[%1],#16\n"
          "  b.eq  2f\n"
          "\n"
          "  dup  v6.4s,v3.s[3]    // just splat\n"
          "  ext  v5.16b,v0.16b,v4.16b,#12\n"
          "  aese  v6.16b,v0.16b\n"
          "\n"
          "  eor  v4.16b,v4.16b,v5.16b\n"
          "  ext  v5.16b,v0.16b,v5.16b,#12\n"
          "  eor  v4.16b,v4.16b,v5.16b\n"
          "  ext  v5.16b,v0.16b,v5.16b,#12\n"
          "  eor  v4.16b,v4.16b,v5.16b\n"
          "\n"
          "  eor  v4.16b,v4.16b,v6.16b\n"
          "  b  1b\n"
          "\n"
          "2:\n" : : "r"(key), "r"(expandedKey), "r"(rcon));
}

/* An ordinary AES round is a sequence of SubBytes, ShiftRows, MixColumns, AddRoundKey. There
 * is also an InitialRound which consists solely of AddRoundKey. The ARM instructions slice
 * this sequence differently; the aese instruction performs AddRoundKey, SubBytes, ShiftRows.
 * The aesmc instruction does the MixColumns. Since the aese instruction moves the AddRoundKey
 * up front, and Cryptonight's hash skips the InitialRound step, we have to kludge it here by
 * feeding in a vector of zeros for our first step. Also we have to do our own Xor explicitly
 * at the last step, to provide the AddRoundKey that the ARM instructions omit.
 */
static INLINE void aes_pseudo_round(const uint8_t *in, uint8_t *out, const uint8_t *expandedKey, int nblocks) {
  const uint8x16_t *k = (const uint8x16_t *)expandedKey;
  uint8x16_t tmp;
  int i;
  
  for (i=0; i<nblocks; i++)
  {
    tmp = R128(in)[i];
    tmp = vaesmcq_u8(vaeseq_u8(tmp, zero));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[0]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[1]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[2]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[3]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[4]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[5]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[6]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[7]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[8]));
    tmp = veorq_u8(tmp,  k[9]);
    R128(out)[i] = tmp;
  }
}

static INLINE void aes_pseudo_round_xor(const uint8_t *in, uint8_t *out, const uint8_t *expandedKey, const uint8_t *xor, int nblocks) {
  const uint8x16_t *k = (const uint8x16_t *)expandedKey;
  const uint8x16_t *x = (const uint8x16_t *)xor;
  uint8x16_t tmp;
  int i;
  
  for (i=0; i<nblocks; i++)
  {
    tmp = R128(in)[i];
    tmp = vaesmcq_u8(vaeseq_u8(tmp, x[i]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[0]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[1]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[2]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[3]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[4]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[5]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[6]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[7]));
    tmp = vaesmcq_u8(vaeseq_u8(tmp, k[8]));
    tmp = veorq_u8(tmp,  k[9]);
    R128(out)[i] = tmp;
  }
}

#else
#error "Invalid architecture"
#endif

#pragma mark - Generic code

union PACKED cn_slow_hash_state {
  union hash_state hs;
  struct PACKED {
    uint8_t k[64];
    uint8_t init[INIT_SIZE_BYTE];
  };
};

void *cn_slow_hash_alloc() { return malloc(MEMORY + AES_KEYEXP_SIZE * 2); }

__attribute__((target("aes")))
void cn_slow_hash(const void *data, size_t length, char *hash, void *buf, uint64_t version) {
  uint8_t *hp_state = buf;
  uint8_t *expandedKey1 = hp_state + MEMORY;
  uint8_t *expandedKey2 = expandedKey1 + AES_KEYEXP_SIZE;

  RDATA_ALIGN16 REG128 _a, _b, _b1, _c, _c1;
  RDATA_ALIGN16 union cn_slow_hash_state state;
  RDATA_ALIGN16 uint64_t hi, lo;
  
  size_t i, j;
  uint8_t tmp, tmp0;
  
  static void (*const extra_hashes[4])(const void *, size_t, char *) = {
    hash_extra_blake, hash_extra_groestl, hash_extra_jh, hash_extra_skein
  };
  
  /* CryptoNight Step 1:  Use Keccak1600 to initialize the 'state' (and 'text') buffers from the data. */
  keccak1600(data, length, &state.hs.b[0]);

  aes_expand_key(state.hs.b, expandedKey1);
  aes_expand_key(&state.hs.b[32], expandedKey2);

  if (version == 1) { assert(length >= 43); }
  const uint64_t tweak1_2 = version == 1 ? (state.hs.w[24] ^ (*((const uint64_t*)(((const uint8_t*)data)+35)))) : 0;

  uint64_t division_result = 0, sqrt_result = 0;
  if (version >= 2) {
    _b1 = xor128(*R128(&state.hs.w[8]), *R128(&state.hs.w[10]));
    division_result = state.hs.w[12];
    sqrt_result = state.hs.w[13];
  } else {
    _b1 = zero;
  }

  /* CryptoNight Step 2:  Iteratively encrypt the results from Keccak to fill
   * the 2MB large random access buffer.
   */
  
  aes_pseudo_round(state.init, &hp_state[0], expandedKey1, INIT_SIZE_BLK);
#pragma clang loop unroll_count(64)
  for(i = 1; i < MEMORY / INIT_SIZE_BYTE; i++) {
    aes_pseudo_round(&hp_state[(i-1) * INIT_SIZE_BYTE], &hp_state[i * INIT_SIZE_BYTE], expandedKey1, INIT_SIZE_BLK);
  }
  
  _a = xor128(*R128(&state.k[ 0]), *R128(&state.k[32]));
  _b = xor128(*R128(&state.k[16]), *R128(&state.k[48]));
  
  /* CryptoNight Step 3:  Bounce randomly 1,048,576 times (1<<20) through the mixing buffer,
   * using 524,288 iterations of the following mixing function.  Each execution
   * performs two reads and writes from the mixing buffer.
   */
  
#pragma clang loop unroll_count(64)
  for(i = 0; i < ITER / 2; i++) {
    j = state_index(_a);
    _c = *R128(&hp_state[j]);
    _c = aesenc(_c, _a);
    if (version >= 2) {
      const REG128 chunk1 = *R128(hp_state + (j ^ 0x10));
      const REG128 chunk2 = *R128(hp_state + (j ^ 0x20));
      const REG128 chunk3 = *R128(hp_state + (j ^ 0x30));
      ((uint64_t*)&chunk1)[0] += ((uint64_t*)&_b)[0];
      ((uint64_t*)&chunk1)[1] += ((uint64_t*)&_b)[1];
      ((uint64_t*)&chunk2)[0] += ((uint64_t*)&_a)[0];
      ((uint64_t*)&chunk2)[1] += ((uint64_t*)&_a)[1];
      ((uint64_t*)&chunk3)[0] += ((uint64_t*)&_b1)[0];
      ((uint64_t*)&chunk3)[1] += ((uint64_t*)&_b1)[1];
      *R128(hp_state + (j ^ 0x10)) = chunk3;
      *R128(hp_state + (j ^ 0x20)) = chunk1;
      *R128(hp_state + (j ^ 0x30)) = chunk2;
    }
    *R128(&hp_state[j]) = xor128(_b, _c);
    if (version == 1) {
      tmp = hp_state[j+11];
      static const uint32_t table = 0x75310;
      tmp0 = (uint8_t)((((tmp >> 3) & 6) | (tmp & 1)) << 1);
      hp_state[j+11] = tmp ^ ((table >> tmp0) & 0x30);
    }

    j = state_index(_c);
    _c1 = *R128(&hp_state[j]);
    if (version >= 2) {
      ((uint64_t*)(&_c1))[0] ^= division_result ^ (sqrt_result << 32);
      const uint64_t dividend = ((uint64_t*)(&_c))[1];
      const uint32_t divisor = (uint32_t)(((uint64_t*)(&_c))[0] + (uint32_t)(sqrt_result << 1)) | 0x80000001UL;
      division_result = ((uint32_t)(dividend / divisor)) + (((uint64_t)(dividend % divisor)) << 32);
      uint64_t sqrt_input = ((uint64_t*)(&_c))[0] + division_result;

      uint64_t r = 1ULL << 63;
      for (uint64_t bit = 1ULL << 60; bit; bit >>= 2) {
        if (sqrt_input < r + bit) {
          r = r >> 1;
        } else {
          sqrt_input = (sqrt_input - (r + bit));
          r = (r + bit * 2) >> 1;
        }
      }
      sqrt_result = (uint32_t)(r * 2 + ((sqrt_input > r) ? 1 : 0));
    }
    mul128(_c, _c1, hi, lo);
    if (version >= 2) {
      *((uint64_t*)(hp_state + (j ^ 0x10)) + 0) ^= hi;
      *((uint64_t*)(hp_state + (j ^ 0x10)) + 1) ^= lo;
      hi ^= *((uint64_t*)(hp_state + (j ^ 0x20)) + 0);
      lo ^= *((uint64_t*)(hp_state + (j ^ 0x20)) + 1);

      const REG128 chunk1 = *R128(hp_state + (j ^ 0x10));
      const REG128 chunk2 = *R128(hp_state + (j ^ 0x20));
      const REG128 chunk3 = *R128(hp_state + (j ^ 0x30));
      ((uint64_t*)&chunk1)[0] += ((uint64_t*)&_b)[0];
      ((uint64_t*)&chunk1)[1] += ((uint64_t*)&_b)[1];
      ((uint64_t*)&chunk2)[0] += ((uint64_t*)&_a)[0];
      ((uint64_t*)&chunk2)[1] += ((uint64_t*)&_a)[1];
      ((uint64_t*)&chunk3)[0] += ((uint64_t*)&_b1)[0];
      ((uint64_t*)&chunk3)[1] += ((uint64_t*)&_b1)[1];
      *R128(hp_state + (j ^ 0x10)) = chunk3;
      *R128(hp_state + (j ^ 0x20)) = chunk1;
      *R128(hp_state + (j ^ 0x30)) = chunk2;
    }
    ((uint64_t*)&_a)[0] += hi; ((uint64_t*)&_a)[1] += lo;
    *R128(&hp_state[j]) = _a;
    _a = xor128(_a, _c1);
    if (version == 1) {
      *(uint64_t*)(hp_state + j + 8) ^= tweak1_2;
    }
    _b1 = _b;
    _b = _c;
  }
  
  /* CryptoNight Step 4:  Sequentially pass through the mixing buffer and use 10 rounds
   * of AES encryption to mix the random data back into the 'text' buffer.  'text'
   * was originally created with the output of Keccak1600. */
  
#pragma clang loop unroll_count(64)
  for(i = 0; i < MEMORY / INIT_SIZE_BYTE; i++) {
    // add the xor to the pseudo round
    aes_pseudo_round_xor(state.init, state.init, expandedKey2, &hp_state[i * INIT_SIZE_BYTE], INIT_SIZE_BLK);
  }
  
  /* CryptoNight Step 5:  Apply Keccak to the state again, and then
   * use the resulting data to select which of four finalizer
   * hash functions to apply to the data (Blake, Groestl, JH, or Skein).
   * Use this hash to squeeze the state array down
   * to the final 256 bit hash output.
   */
  
  keccakf(state.hs.w, 24);
  extra_hashes[state.hs.b[0] & 3](&state, 200, hash);
}

