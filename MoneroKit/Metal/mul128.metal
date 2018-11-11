static inline __attribute__((always_inline)) void mul128(const uint2 ca, const uint2 cb, thread uint4 &cres) {
  _uint64_t ltmp[4];
  thread uint32_t *tmp = (thread uint32_t*)ltmp;

  _uint64_t A = ca.y;
  _uint64_t a = ca.x;
  _uint64_t B = cb.y;
  _uint64_t b = cb.x;

  ltmp[0] = a * b;
  ltmp[1] = a * B;
  ltmp[2] = A * b;
  ltmp[3] = A * B;

  ltmp[1] += tmp[1];
  ltmp[1] += tmp[4];
  ltmp[3] += tmp[3];
  ltmp[3] += tmp[5];
  cres = uint4(tmp[6], tmp[7], tmp[0], tmp[2]);
}
