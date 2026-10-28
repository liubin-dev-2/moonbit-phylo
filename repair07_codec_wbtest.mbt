///|
test "repair07 finite binary64 exponent and mantissa boundary round trips" {
  for exponent = 0; exponent < 2047; exponent = exponent + 1 {
    for mantissa in [0UL, 1UL, 0x000fffffffffffffUL] {
      let bits = (exponent.to_uint64() << 52) | mantissa
      let value = bits.reinterpret_as_double()
      assert_eq(
        rounded_length(length_units(value)).reinterpret_as_uint64(),
        bits,
      )
    }
  }
}
