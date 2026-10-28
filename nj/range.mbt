///|
let retry_units : Double = 256.0

///|
// Scaling is used only after the original construction reports overflow.
// Normal-range operations commute with this exact power-of-two unit change;
// reject gradual underflow rather than silently losing smaller distances.
fn distance_value(
  value : Double,
  stage : String,
  units : Double,
) -> Double raise NJFailure {
  let value = finite(value, stage)
  if units != 1.0 {
    let magnitude = if value < 0.0 { -value } else { value }
    if magnitude != 0.0 &&
      magnitude < 0x0010000000000000UL.reinterpret_as_double() {
      raise NJFault(NumericOverflow(stage + "_scaled_range"))
    }
  }
  value
}

///|
fn distance_quotient(
  numerator : Double,
  denominator : Double,
  stage : String,
  units : Double,
) -> Double raise NJFailure {
  let value = distance_value(numerator / denominator, stage, units)
  if units != 1.0 && numerator != 0.0 && value == 0.0 {
    raise NJFault(NumericOverflow(stage + "_scaled_underflow"))
  }
  value
}

///|
fn retry_matrix(
  matrix : @phylo.DistanceMatrix,
) -> @phylo.DistanceMatrix raise NJFailure {
  let values = matrix.values.map(row => {
    row.map(value => {
      let scaled = value / retry_units
      if value != 0.0 &&
        (
          scaled < 0x0010000000000000UL.reinterpret_as_double() ||
          scaled * retry_units != value
        ) {
        raise NJFault(NumericOverflow("scale_input_range"))
      }
      scaled
    })
  })
  { taxa: matrix.taxa.copy(), values, }
}

///|
fn build_nj(matrix : @phylo.DistanceMatrix) -> String raise NJFailure {
  build_nj_in_units(matrix, 1.0) catch {
    NJFault(NumericOverflow(_)) =>
      build_nj_in_units(retry_matrix(matrix), retry_units)
    NJFault(error) => raise NJFault(error)
  }
}
