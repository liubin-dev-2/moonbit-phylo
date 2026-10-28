///|
fn canonical(
  matrix : @phylo.DistanceMatrix,
) -> @phylo.DistanceMatrix raise NJFailure {
  let n = matrix.taxa.length()
  if n < 2 || n > 128 {
    raise NJFault(InvalidSize(n))
  }
  if matrix.values.length() != n {
    raise NJFault(InvalidShape(-1, n, matrix.values.length()))
  }
  let seen : Map[String, Bool] = Map([])
  for i = 0; i < n; i = i + 1 {
    let name = matrix.taxa[i]
    if name.is_empty() {
      raise NJFault(EmptyTaxon(i))
    }
    if seen.contains(name) {
      raise NJFault(DuplicateTaxon(name))
    }
    seen[name] = true
    if matrix.values[i].length() != n {
      raise NJFault(InvalidShape(i, n, matrix.values[i].length()))
    }
  }
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      let value = matrix.values[i][j]
      if value.is_nan() || value.is_inf() {
        raise NJFault(NonFinite(i, j))
      }
      if value < 0.0 {
        raise NJFault(NegativeDistance(i, j))
      }
      if i == j && value != 0.0 {
        raise NJFault(NonzeroDiagonal(i))
      }
    }
  }
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      if matrix.values[i][j] != matrix.values[j][i] {
        raise NJFault(Asymmetric(i, j))
      }
    }
  }
  let order = Array::makei(n, i => i)
  order.sort_by((a, b) => matrix.taxa[a].lexical_compare(matrix.taxa[b]))
  {
    taxa: order.map(i => matrix.taxa[i]),
    values: order.map(i => {
      order.map(j => {
        let x = matrix.values[i][j]
        if x == 0.0 {
          0.0
        } else {
          x
        }
      })
    }),
  }
}

///|
/// Build an explicitly unrooted NJ tree from a 2..128 exact-label matrix.
/// Finite arithmetic and nonnegative branches are required; negative limbs are
/// errors, never clipped. Q ties follow canonical keep-then-append order.
pub fn neighbor_joining(
  matrix : @phylo.DistanceMatrix,
) -> Result[NJReport, NJError] {
  try {
    let input = canonical(matrix)
    let tree = match @phylo.PhyloTree::from_newick(build_nj(input)) {
      Ok(tree) => tree
      Err(error) => raise NJFault(CoreError(error))
    }
    let fitted = match tree.patristic_matrix() {
      Ok(fitted) => fitted
      Err(@phylo.NumericOverflow) =>
        raise NJFault(NumericOverflow("fitted_paths"))
      Err(error) => raise NJFault(CoreError(error))
    }
    let n = input.taxa.length()
    let residuals = Array::makei(n, _ => Array::make(n, 0.0))
    let mut max_abs_residual = 0.0
    for i = 0; i < n; i = i + 1 {
      for j = i + 1; j < n; j = j + 1 {
        let r = finite(fitted.values[i][j] - input.values[i][j], "residual")
        residuals[i][j] = r
        residuals[j][i] = r
        let magnitude = if r < 0.0 { -r } else { r }
        if magnitude > max_abs_residual {
          max_abs_residual = magnitude
        }
      }
    }
    let mut squares = 0.0
    if max_abs_residual > 0.0 {
      for i = 0; i < n; i = i + 1 {
        for j = i + 1; j < n; j = j + 1 {
          let scaled = residuals[i][j] / max_abs_residual
          squares = squares + scaled * scaled
        }
      }
    }
    let pairs = (n * (n - 1) / 2).to_double()
    let rms_residual = finite(
      max_abs_residual * (squares / pairs).sqrt(),
      "rms",
    )
    Ok({ tree, input, fitted, residuals, max_abs_residual, rms_residual, })
  } catch {
    NJFault(error) => Err(error)
  }
}
