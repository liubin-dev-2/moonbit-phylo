///|
pub(all) enum NJError {
  InvalidJson
  InvalidField(String)
  InvalidSize(Int)
  InvalidShape(Int, Int, Int)
  EmptyTaxon(Int)
  DuplicateTaxon(String)
  NonFinite(Int, Int)
  NegativeDistance(Int, Int)
  NonzeroDiagonal(Int)
  Asymmetric(Int, Int)
  NumericOverflow(String)
  NegativeLimb(Array[String], Double)
  CoreError(@phylo.PhyloError)
} derive(Debug)

///|
/// Arrays describe canonical exact-label order. Residuals are fitted minus input;
/// RMS is over unordered pairs. Node IDs belong to tree only.
pub(all) struct NJReport {
  tree : @phylo.PhyloTree
  input : @phylo.DistanceMatrix
  fitted : @phylo.DistanceMatrix
  residuals : Array[Array[Double]]
  max_abs_residual : Double
  rms_residual : Double
}

///|
priv suberror NJFailure {
  NJFault(NJError)
}

///|
fn finite(value : Double, stage : String) -> Double raise NJFailure {
  if value.is_nan() || value.is_inf() {
    raise NJFault(NumericOverflow(stage))
  }
  value
}
