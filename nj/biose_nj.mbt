// Adapted from IvanAXu/BioSeqs 0.1.9 src/tree_construction.mbt (Apache-2.0).
// Changes: compact private nodes, checked arithmetic, deterministic canonical
// input, explicit negative-limb errors, two-tip path preservation and a final
// unrooted three-cluster star. Overflow-only guarded power-of-two retry restores
// limbs to input units. See UPSTREAM.md and LICENSE-BioSeqs.

///|
priv struct BuildNode {
  name : String
  children : Array[BuildNode]
  branch_lengths : Array[Double]
}

///|
fn build_node_leaf(name : String) -> BuildNode {
  { name, children: [], branch_lengths: [], }
}

///|
fn build_taxa(node : BuildNode) -> Array[String] {
  if node.children.is_empty() {
    [node.name]
  } else {
    let names = []
    for child in node.children {
      names.append(build_taxa(child))
    }
    names.sort_by((a, b) => a.lexical_compare(b))
    names
  }
}

///|
fn limb(
  value : Double,
  node : BuildNode,
  units : Double,
  negative_hint : Bool,
) -> Double raise NJFailure {
  let value = finite(value, "limb")
  let value = if units == 1.0 {
    value
  } else {
    finite(value * units, "limb_rescale")
  }
  // Preserve evidence of a tiny negative that rounded to signed zero.
  if negative_hint ||
    value < 0.0 ||
    value.reinterpret_as_uint64() == 0x8000000000000000UL {
    raise NJFault(NegativeLimb(build_taxa(node), value))
  }
  value
}

///|
fn build_newick(node : BuildNode) -> String {
  if node.children.is_empty() {
    "'" + node.name.replace_all(old="'", new="''") + "'"
  } else {
    let parts = node.children.mapi((i, child) => {
      build_newick(child) + ":" + node.branch_lengths[i].to_string()
    })
    "(" + parts.join(",") + ")"
  }
}

///|
// The published NJ row sums, Q criterion, limb equations, reduced distances
// and keep-then-append order are retained. Only this construction subset is used.
fn build_nj_in_units(
  matrix : @phylo.DistanceMatrix,
  units : Double,
) -> String raise NJFailure {
  let mut active = matrix.taxa.map(build_node_leaf)
  let mut dist = matrix.values.map(row => row.copy())
  if active.length() == 2 {
    return "[&U]" +
      build_newick({
        name: "",
        children: active,
        branch_lengths: [0.0, limb(dist[0][1], active[1], units, false)],
      }) +
      ";"
  }
  while active.length() > 3 {
    let m = active.length()
    let factor = (m - 2).to_double()
    let row_sums = Array::make(m, 0.0)
    for i = 0; i < m; i = i + 1 {
      for j = 0; j < m; j = j + 1 {
        row_sums[i] = distance_value(row_sums[i] + dist[i][j], "row_sum", units)
      }
    }
    let mut min_q : Double? = None
    let mut min_i = 0
    let mut min_j = 1
    for i = 0; i < m; i = i + 1 {
      for j = i + 1; j < m; j = j + 1 {
        let sum = distance_value(row_sums[i] + row_sums[j], "q_sum", units)
        let q = distance_value(
          dist[i][j] - distance_quotient(sum, factor, "q_scale", units),
          "q",
          units,
        )
        if min_q is None || q < min_q.unwrap() {
          min_q = Some(q)
          min_i = i
          min_j = j
        }
      }
    }
    let dij = dist[min_i][min_j]
    let delta = distance_value(
      row_sums[min_i] - row_sums[min_j],
      "limb_difference",
      units,
    )
    let half = distance_quotient(dij, 2.0, "limb_half", units)
    let correction = distance_quotient(
      delta,
      2.0 * factor,
      "limb_correction",
      units,
    )
    let diu = distance_value(half + correction, "limb_sum", units)
    let left_length = limb(diu, active[min_i], units, false)
    let dju = distance_value(dij - diu, "limb_remainder", units)
    let right_length = limb(dju, active[min_j], units, false)
    let merged = {
      name: "",
      children: [active[min_i], active[min_j]],
      branch_lengths: [left_length, right_length],
    }
    let keep = []
    for k = 0; k < m; k = k + 1 {
      if k != min_i && k != min_j {
        keep.push(k)
      }
    }
    let reduced = keep.map(k => {
      let sum = distance_value(
        dist[min_i][k] + dist[min_j][k],
        "reduced_sum",
        units,
      )
      distance_quotient(
        distance_value(sum - dij, "reduced_difference", units),
        2.0,
        "reduced_half",
        units,
      )
    })
    let next_dist = keep.mapi((r, kr) => {
      let row = keep.map(kc => dist[kr][kc])
      row.push(reduced[r])
      row
    })
    let last = reduced.copy()
    last.push(0.0)
    next_dist.push(last)
    let next_active = keep.map(k => active[k])
    next_active.push(merged)
    active = next_active
    dist = next_dist
  }
  let lengths = Array::make(3, 0.0)
  for i = 0; i < 3; i = i + 1 {
    let j = (i + 1) % 3
    let k = (i + 2) % 3
    let sum = distance_value(dist[i][j] + dist[i][k], "star_sum", units)
    let numerator = distance_value(sum - dist[j][k], "star_difference", units)
    // Remember the sign before division, but report the actual branch length.
    let negative = numerator < 0.0
    let value = distance_quotient(numerator, 2.0, "star_half", units)
    lengths[i] = limb(value, active[i], units, negative)
  }
  "[&U]" +
  build_newick({ name: "", children: active, branch_lengths: lengths, }) +
  ";"
}
