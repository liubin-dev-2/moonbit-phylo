// Adapted from IvanAXu/BioSeqs 0.1.9 src/tree_construction.mbt (Apache-2.0).
// Changes: compact private nodes, checked arithmetic, deterministic canonical
// input, explicit negative-limb errors, two-tip path preservation and a final
// unrooted three-cluster star. See UPSTREAM.md and LICENSE-BioSeqs.

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
fn limb(value : Double, node : BuildNode) -> Double raise NJFailure {
  let value = finite(value, "limb")
  // Preserve evidence of a tiny negative that rounded to signed zero.
  if value < 0.0 || value.reinterpret_as_uint64() == 0x8000000000000000UL {
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
fn build_nj(matrix : @phylo.DistanceMatrix) -> String raise NJFailure {
  let mut active = matrix.taxa.map(build_node_leaf)
  let mut dist = matrix.values.map(row => row.copy())
  if active.length() == 2 {
    return "[&U]" +
      build_newick({
        name: "",
        children: active,
        branch_lengths: [0.0, dist[0][1]],
      }) +
      ";"
  }
  while active.length() > 3 {
    let m = active.length()
    let factor = (m - 2).to_double()
    let row_sums = Array::make(m, 0.0)
    for i = 0; i < m; i = i + 1 {
      for j = 0; j < m; j = j + 1 {
        row_sums[i] = finite(row_sums[i] + dist[i][j], "row_sum")
      }
    }
    let mut min_q : Double? = None
    let mut min_i = 0
    let mut min_j = 1
    for i = 0; i < m; i = i + 1 {
      for j = i + 1; j < m; j = j + 1 {
        let sum = finite(row_sums[i] + row_sums[j], "q_sum")
        let q = finite(dist[i][j] - finite(sum / factor, "q_scale"), "q")
        if min_q is None || q < min_q.unwrap() {
          min_q = Some(q)
          min_i = i
          min_j = j
        }
      }
    }
    let dij = dist[min_i][min_j]
    let delta = finite(row_sums[min_i] - row_sums[min_j], "limb_difference")
    let half = finite(dij / 2.0, "limb_half")
    let correction = finite(delta / (2.0 * factor), "limb_correction")
    let diu = limb(finite(half + correction, "limb_sum"), active[min_i])
    let dju = limb(finite(dij - diu, "limb_remainder"), active[min_j])
    let merged = {
      name: "",
      children: [active[min_i], active[min_j]],
      branch_lengths: [diu, dju],
    }
    let keep = []
    for k = 0; k < m; k = k + 1 {
      if k != min_i && k != min_j {
        keep.push(k)
      }
    }
    let reduced = keep.map(k => {
      let sum = finite(dist[min_i][k] + dist[min_j][k], "reduced_sum")
      finite(finite(sum - dij, "reduced_difference") / 2.0, "reduced_half")
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
    let sum = finite(dist[i][j] + dist[i][k], "star_sum")
    let numerator = finite(sum - dist[j][k], "star_difference")
    // Remember the sign before division, but report the actual branch length.
    let negative = numerator < 0.0
    let value = finite(numerator / 2.0, "star_half")
    if negative {
      raise NJFault(NegativeLimb(build_taxa(active[i]), value))
    }
    lengths[i] = limb(value, active[i])
  }
  "[&U]" +
  build_newick({ name: "", children: active, branch_lengths: lengths, }) +
  ";"
}
