///|
// Compact in postorder; surviving taxa are specified by original node identity,
// so an old unlabeled root never accidentally becomes a new taxon after rerooting.
fn compact(
  source : PhyloTree,
  keep : Array[Bool],
  original_count : Int,
) -> (PhyloTree, Array[Int?], Array[Array[Int]]) raise Failure {
  let order = traversal(source)
  let out : Array[Node] = []
  let totals : Array[@bigint.BigInt?] = []
  let representative : Array[Int?] = Array::make(source.arena.length(), None)
  let mapping : Array[Int?] = Array::make(original_count, None)
  let paths : Array[Array[Int]] = []
  for k = order.length() - 1; k >= 0; k = k - 1 {
    let old = order[k]
    let n = source.arena[old]
    let children : Array[Int] = []
    for c in n.children {
      if representative[c] is Some(id) {
        children.push(id)
      }
    }
    if children.is_empty() && !keep[old] {
      continue
    }
    if children.length() == 1 && !keep[old] {
      let c = children[0]
      if old != source.root {
        totals[c] = match (n.length, totals[c]) {
          (Some(a), Some(b)) =>
            // Preserve unknown propagation over the entire path and round
            // complete path sums only once, when they become retained edges.
            Some(length_units(a) + b)
          _ => None
        }
      }
      paths[c].insert(0, old)
      representative[old] = Some(c)
      continue
    }
    let id = out.length()
    let nn = new_node(None, n.label)
    nn.length = n.length
    nn.children.append(children)
    nn.comments.append(n.comments)
    for c in children {
      out[c].parent = Some(id)
    }
    out.push(nn)
    totals.push(
      match n.length {
        Some(x) => Some(length_units(x))
        None => None
      },
    )
    paths.push([old])
    representative[old] = Some(id)
    if old < original_count {
      mapping[old] = Some(id)
    }
  }
  let root = representative[source.root].unwrap()
  out[root].parent = None
  // Retain the authored stem only if the authored root survives.
  out[root].length = if mapping.get(source.root) == Some(Some(root)) {
    source.arena[source.root].length
  } else {
    None
  }
  for id, n in out {
    if id != root {
      n.length = match totals[id] {
        Some(x) => Some(rounded_length(x))
        None => None
      }
      if n.length is Some(x) && x.is_inf() {
        raise Fault(NumericOverflow)
      }
    }
  }
  (
    PhyloTree::{
      arena: out,
      root,
      rooting: source.rooting,
      comments: source.comments.copy(),
    },
    mapping,
    paths,
  )
}

///|
pub fn PhyloTree::prune(
  self : PhyloTree,
  retain : Array[String],
) -> Result[TransformResult, PhyloError] {
  if retain.is_empty() {
    return Err(EmptySelection)
  }
  let taxa = self.taxa()
  let seen : Array[String] = []
  for t in retain {
    if !taxa.contains(t) {
      return Err(UnknownTaxon(t))
    }
    if seen.contains(t) {
      return Err(DuplicateSelection(t))
    }
    seen.push(t)
  }
  let keep = self.arena.map(n => {
    n.children.is_empty() && retain.contains(n.label.unwrap())
  })
  try {
    // Choose the retained LCA before adding any lengths. Its ancestry will
    // become a discarded stem, not a new tree edge that needs a finite sum.
    let count = Array::make(self.arena.length(), 0)
    let order = traversal(self)
    for k = order.length() - 1; k >= 0; k = k - 1 {
      let id = order[k]
      if keep[id] {
        count[id] = 1
      }
      for child in self.arena[id].children {
        count[id] = count[id] + count[child]
      }
    }
    let mut root = self.root
    let discarded = []
    while !keep[root] {
      let children = self.arena[root].children.filter(c => count[c] > 0)
      if children.length() != 1 {
        break
      }
      discarded.push(root)
      root = children[0]
    }
    let view = PhyloTree::{
      arena: self.arena,
      root,
      rooting: self.rooting,
      comments: self.comments,
    }
    let (tree, mapping, paths) = compact(view, keep, self.arena.length())
    if root != self.root {
      tree.arena[tree.root].length = None
      discarded.append(paths[tree.root])
      paths[tree.root] = discarded
    }
    Ok({
      tree,
      witness: {
        old_to_new: mapping,
        retained_taxa: tree.taxa(),
        edge_paths: paths,
        diameter_endpoints: [],
        diameter: None,
        split_edge: [],
        offset: None,
      },
    })
  } catch {
    Fault(e) => Err(e)
  }
}

///|
pub fn PhyloTree::midpoint_root(
  self : PhyloTree,
) -> Result[TransformResult, PhyloError] {
  try {
    check_lengths(self)
    let ids = leaf_ids(self)
    let mut diameter = 0.0
    let mut start = ids[0]
    let mut finish = ids[0]
    for i = 0; i < ids.length(); i = i + 1 {
      let (d, _) = paths_from(self, ids[i])
      for j = i + 1; j < ids.length(); j = j + 1 {
        if d[ids[j]].is_inf() {
          raise Fault(NumericOverflow)
        }
        if d[ids[j]] > diameter {
          diameter = d[ids[j]]
          start = ids[i]
          finish = ids[j]
        }
      }
    }
    if diameter == 0.0 {
      let tree = PhyloTree::{
        arena: self.arena,
        root: self.root,
        rooting: Rooted,
        comments: self.comments.copy(),
      }
      return Ok({
        tree,
        witness: {
          old_to_new: Array::makei(self.arena.length(), i => Some(i)),
          retained_taxa: self.taxa(),
          edge_paths: Array::makei(self.arena.length(), i => [i]),
          diameter_endpoints: [
            self.arena[ids[0]].label.unwrap(),
            self.arena[ids[ids.length() - 1]].label.unwrap(),
          ],
          diameter: Some(0.0),
          split_edge: [],
          offset: Some(0.0),
        },
      })
    }
    let (_, parents) = paths_from(self, start)
    let path : Array[Int] = []
    let mut v = finish
    while v != start {
      path.push(v)
      v = parents[v]
    }
    path.push(start)
    for i = 0; i < path.length() / 2; i = i + 1 {
      let j = path.length() - 1 - i
      let temp = path[i]
      path[i] = path[j]
      path[j] = temp
    }
    // Locate half the exact selected path, before rounding its public diameter.
    // Doubled coordinates keep even half-subnormal midpoints integral.
    let zero = @bigint.BigInt::from_int(0)
    let mut remaining = zero
    for i = 0; i + 1 < path.length(); i = i + 1 {
      remaining = remaining +
        length_units(edge_length(self, path[i], path[i + 1]))
    }
    let mut new_root = -1
    let mut cut_a = -1
    let mut cut_b = -1
    let mut offset = 0.0
    for i = 0; i + 1 < path.length(); i = i + 1 {
      let a = path[i]
      let b = path[i + 1]
      let len = edge_length(self, a, b)
      let twice_len = length_units(len) << 1
      if remaining == zero {
        new_root = a
        break
      }
      if remaining < twice_len {
        cut_a = a
        cut_b = b
        offset = rounded_half_length(remaining)
        break
      }
      remaining = remaining - twice_len
      if remaining == zero {
        new_root = b
        break
      }
    }
    // Binary64 may round half of a positive subnormal diameter to zero.
    // Keep a terminal taxon terminal: insert an explicit zero-length edge
    // instead of turning the selected endpoint into an internal taxon node.
    if new_root >= 0 && self.arena[new_root].children.is_empty() {
      if new_root == start {
        cut_a = path[0]
        cut_b = path[1]
        offset = 0.0
      } else {
        cut_a = path[path.length() - 2]
        cut_b = path[path.length() - 1]
        offset = edge_length(self, cut_a, cut_b)
      }
      new_root = -1
    }
    let count = self.arena.length()
    let extra = if new_root < 0 { 1 } else { 0 }
    if extra == 1 {
      new_root = count
    }
    let graph : Array[Array[(Int, Double)]] = Array::makei(count + extra, _ => {
      []
    })
    for id, n in self.arena {
      if n.parent is Some(p) {
        if (id == cut_a && p == cut_b) || (id == cut_b && p == cut_a) {
          continue
        }
        graph[id].push((p, n.length.unwrap()))
        graph[p].push((id, n.length.unwrap()))
      }
    }
    if extra == 1 {
      let len = edge_length(self, cut_a, cut_b)
      graph[new_root].push((cut_a, offset))
      graph[cut_a].push((new_root, offset))
      graph[new_root].push((cut_b, len - offset))
      graph[cut_b].push((new_root, len - offset))
    }
    let arena : Array[Node] = Array::makei(count + extra, i => {
      let n = new_node(None, if i < count { self.arena[i].label } else { None })
      if i < count {
        n.comments.append(self.arena[i].comments)
      }
      n
    })
    let visited = Array::make(count + extra, false)
    visited[new_root] = true
    let stack = [new_root]
    while !stack.is_empty() {
      let a = stack.pop().unwrap()
      for item in graph[a] {
        let (b, len) = item
        if !visited[b] {
          visited[b] = true
          arena[b].parent = Some(a)
          arena[b].length = Some(len)
          arena[a].children.push(b)
          stack.push(b)
        }
      }
    }
    let oriented = PhyloTree::{
      arena,
      root: new_root,
      rooting: Rooted,
      comments: self.comments.copy(),
    }
    let keep = Array::makei(count + extra, i => {
      i < count && self.arena[i].children.is_empty()
    })
    let (tree, mapping, paths) = compact(oriented, keep, count)
    Ok({
      tree,
      witness: {
        old_to_new: mapping,
        retained_taxa: tree.taxa(),
        edge_paths: paths,
        diameter_endpoints: [
          self.arena[start].label.unwrap(),
          self.arena[finish].label.unwrap(),
        ],
        diameter: Some(diameter),
        split_edge: if extra == 1 {
          [cut_a, cut_b]
        } else {
          []
        },
        offset: if extra == 1 {
          Some(offset)
        } else {
          None
        },
      },
    })
  } catch {
    Fault(e) => Err(e)
  }
}
