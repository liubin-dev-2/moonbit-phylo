///|
// A finite nonnegative binary64 value is an integer multiple of 2^-1074.
// Exact internal units avoid order-dependent rounding and false overflow.
fn length_units(value : Double) -> @bigint.BigInt {
  let bits = value.reinterpret_as_uint64()
  let exponent = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0x000fffffffffffffUL
  if exponent == 0 {
    @bigint.BigInt::from_uint64(fraction)
  } else {
    @bigint.BigInt::from_uint64(fraction | 0x0010000000000000UL) <<
    (exponent - 1)
  }
}

///|
// Round once to nearest binary64, resolving halfway cases toward even.
fn rounded_length(units : @bigint.BigInt) -> Double {
  round_length_units(units, false)
}

///|
// Midpoint offsets can be half a 2^-1074 unit. Keep that final bit until rounding.
fn rounded_half_length(units : @bigint.BigInt) -> Double {
  round_length_units(units, true)
}

///|
fn round_length_units(units : @bigint.BigInt, half : Bool) -> Double {
  let fractional_bits = if half { 1 } else { 0 }
  let width = units.bit_length()
  let precision_shift = if width > 53 { width - 53 } else { 0 }
  let shift = if precision_shift > fractional_bits {
    precision_shift
  } else {
    fractional_bits
  }
  let leading = units >> shift
  let mut mantissa = leading.to_uint64()
  if shift > 0 {
    let remainder = units - (leading << shift)
    let half = @bigint.BigInt::from_int(1) << (shift - 1)
    if remainder > half || (remainder == half && (mantissa & 1UL) == 1UL) {
      mantissa = mantissa + 1UL
    }
  }
  if width <= 52 + fractional_bits {
    return mantissa.reinterpret_as_double()
  }
  let mut exponent = width - 52 - fractional_bits
  if mantissa == 0x0020000000000000UL {
    mantissa = mantissa >> 1
    exponent = exponent + 1
  }
  if exponent >= 2047 {
    return 0x7ff0000000000000UL.reinterpret_as_double()
  }
  ((exponent.to_uint64() << 52) | (mantissa - 0x0010000000000000UL)).reinterpret_as_double()
}
