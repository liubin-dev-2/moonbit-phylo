///|
fn check_lengths(tree : PhyloTree) -> Unit raise Failure {
  for id, n in tree.arena {
    if id != tree.root {
      guard n.length is Some(x) else { raise Fault(MissingLength(id)) }
      if x.is_nan() || x.is_inf() || x < 0.0 {
        raise Fault(InvalidLength(id, x.to_string()))
      }
    }
  }
}

///|
fn neighbors(tree : PhyloTree, id : Int) -> Array[Int] {
  let n = tree.arena[id]
  let out = n.children.copy()
  if n.parent is Some(p) {
    out.push(p)
  }
  out
}

///|
fn edge_length(tree : PhyloTree, a : Int, b : Int) -> Double {
  if tree.arena[a].parent == Some(b) {
    tree.arena[a].length.unwrap()
  } else {
    tree.arena[b].length.unwrap()
  }
}

///|
fn paths_from(tree : PhyloTree, source : Int) -> (Array[Double], Array[Int]) {
  let distance = Array::make(tree.arena.length(), @bigint.BigInt::from_int(0))
  let parent = Array::make(tree.arena.length(), -2)
  parent[source] = -1
  let stack = [source]
  while !stack.is_empty() {
    let a = stack.pop().unwrap()
    for b in neighbors(tree, a) {
      if parent[b] == -2 {
        parent[b] = a
        distance[b] = distance[a] + length_units(edge_length(tree, a, b))
        // A dangling root-side path can overflow without any requested
        // leaf-to-leaf path overflowing. Callers validate their leaf results.
        stack.push(b)
      }
    }
  }
  (distance.map(rounded_length), parent)
}

///|
pub fn PhyloTree::patristic_distance(
  self : PhyloTree,
  from : String,
  to : String,
) -> Result[Double, PhyloError] {
  try {
    check_lengths(self)
    let ids = leaf_ids(self)
    let mut a = -1
    let mut b = -1
    for id in ids {
      if self.arena[id].label == Some(from) {
        a = id
      }
      if self.arena[id].label == Some(to) {
        b = id
      }
    }
    if a < 0 {
      raise Fault(UnknownTaxon(from))
    }
    if b < 0 {
      raise Fault(UnknownTaxon(to))
    }
    let ancestors = Array::make(self.arena.length(), false)
    let mut current = a
    while true {
      ancestors[current] = true
      match self.arena[current].parent {
        Some(p) => current = p
        None => break
      }
    }
    let mut common = b
    while !ancestors[common] {
      common = self.arena[common].parent.unwrap()
    }
    let mut total = @bigint.BigInt::from_int(0)
    for start in [a, b] {
      let mut node = start
      while node != common {
        total = total + length_units(self.arena[node].length.unwrap())
        node = self.arena[node].parent.unwrap()
      }
    }
    let distance = rounded_length(total)
    if distance.is_inf() {
      raise Fault(NumericOverflow)
    }
    Ok(distance)
  } catch {
    Fault(e) => Err(e)
  }
}

///|
pub fn PhyloTree::patristic_matrix(
  self : PhyloTree,
) -> Result[DistanceMatrix, PhyloError] {
  try {
    check_lengths(self)
    let ids = leaf_ids(self)
    let values = []
    for id in ids {
      let (d, _) = paths_from(self, id)
      let row = []
      for j in ids {
        if d[j].is_inf() {
          raise Fault(NumericOverflow)
        }
        row.push(d[j])
      }
      values.push(row)
    }
    Ok({ taxa: self.taxa(), values, })
  } catch {
    Fault(e) => Err(e)
  }
}
