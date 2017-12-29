#define KECCAK_ROUNDS 24
#define HASH_DATA_AREA 136
#define ROTL64(x, y) (((x) << (y)) | ((x) >> (64 - (y))))

typedef size_t uint64_t;
typedef uint64_t state_t[25];

constant static const uint64_t keccakf_rndc[24] = {
  0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
  0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
  0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
  0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
  0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
  0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
  0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
  0x8000000000008080, 0x0000000080000001, 0x8000000080008008
};

constant static const uint32_t keccakf_rotc[24] = {
  1,  3,  6,  10, 15, 21, 28, 36, 45, 55, 2,  14,
  27, 41, 56, 8,  25, 43, 62, 18, 39, 61, 20, 44
};

constant static const uint32_t keccakf_piln[24] = {
  10, 7,  11, 17, 18, 3, 5,  16, 8,  21, 24, 4,
  15, 23, 19, 13, 12, 2, 20, 14, 22, 9,  6,  1
};

static inline __attribute__((always_inline)) void keccakf(state_t &st, uint32_t rounds) {
  uint32_t i, j, r;
  uint64_t t;
  uint64_t __attribute__((aligned(16))) bc[5];
  
  for (r = 0; r < rounds; r++) {
    for (i = 0; i < 5; i++)
      bc[i] = st[i] ^ st[i + 5] ^ st[i + 10] ^ st[i + 15] ^ st[i + 20];
    for (i = 0; i < 5; i++) {
      t = bc[(i + 4) % 5] ^ ROTL64(bc[(i + 1) % 5], 1);
      st[0 + i] ^= t;
      st[5 + i] ^= t;
      st[10 + i] ^= t;
      st[15 + i] ^= t;
      st[20 + i] ^= t;
    }
    t = st[1];
    for (i = 0; i < 24; i++) {
      j = keccakf_piln[i];
      bc[0] = st[j];
      st[j] = ROTL64(t, keccakf_rotc[i]);
      t = bc[0];
    }

    for (i = 0; i < 5; i++)
      bc[i] = st[0 + i];
    for (i = 0; i < 5; i++)
      st[0 + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];

    for (i = 0; i < 5; i++)
      bc[i] = st[5 + i];
    for (i = 0; i < 5; i++)
      st[5 + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];

    for (i = 0; i < 5; i++)
      bc[i] = st[10 + i];
    for (i = 0; i < 5; i++)
      st[10 + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];

    for (i = 0; i < 5; i++)
      bc[i] = st[15 + i];
    for (i = 0; i < 5; i++)
      st[15 + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];

    for (i = 0; i < 5; i++)
      bc[i] = st[20 + i];
    for (i = 0; i < 5; i++)
      st[20 + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];

    st[0] ^= keccakf_rndc[r];
  }
}

static inline __attribute__((always_inline)) void keccak(const device uint8_t *in, size_t inlen, device uint8_t *md, size_t mdlen) {
  state_t __attribute__((aligned(16))) st;
  uint8_t temp[144];
  size_t i, rsiz, rsizw, inoff = 0;

  rsiz = sizeof(state_t) == mdlen ? HASH_DATA_AREA : 200 - 2 * mdlen;
  rsizw = rsiz / 8;

  for (i = 0; i < sizeof(st) / 8; i++) st[i] = 0;

  for ( ; inlen >= rsiz; inlen -= rsiz, inoff += rsiz) {
    for (i = 0; i < rsizw; i++) st[i] ^= ((const device uint64_t*)(in + inoff))[i];
    keccakf(st, KECCAK_ROUNDS);
  }

  for (i = 0; i < inlen; i++) ((thread uint8_t*)temp)[i] = ((const device uint8_t*)(in + inoff))[i];
  inoff += inlen;
  temp[inlen++] = 1;
  for (i = 0; i < rsiz - inlen; i++) ((thread uint8_t*)temp)[inlen + i] = 0;
  temp[rsiz - 1] |= 0x80;
  for (i = 0; i < rsizw; i++) st[i] ^= ((const thread uint64_t*)temp)[i];
  keccakf(st, KECCAK_ROUNDS);

  for (i = 0; i < mdlen; i++) md[i] = ((const thread uint8_t*)st)[i];
}

static inline __attribute__((always_inline)) void keccak1600(const device uint8_t *in, size_t inlen, device uint8_t *md) {
  keccak(in, inlen, md, sizeof(state_t));
}
