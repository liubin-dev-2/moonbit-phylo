///|
fn split_sets(tree : PhyloTree, rooted : Bool) -> Array[Array[String]] {
  let order = traversal(tree)
  let all = tree.taxa()
  let sets : Array[Array[String]] = Array::makei(tree.arena.length(), _ => [])
  let result : Array[Array[String]] = []
  for i = order.length() - 1; i >= 0; i = i - 1 {
    let id = order[i]
    let n = tree.arena[id]
    if n.children.is_empty() {
      sets[id].push(n.label.unwrap())
    } else {
      for child in n.children {
        sets[id].append(sets[child])
      }
    }
    sets[id].sort_by((a, b) => a.lexical_compare(b))
    let s = sets[id]
    let count = s.length()
    if rooted {
      if count > 1 && count < all.length() && !result.contains(s) {
        result.push(s.copy())
      }
    } else if count >= 2 && all.length() - count >= 2 {
      let canonical = if s.contains(all[0]) {
        all.filter(x => !s.contains(x))
      } else {
        s.copy()
      }
      if !result.contains(canonical) {
        result.push(canonical)
      }
    }
  }
  result.sort_by(compare_labels)
  result
}

///|
fn rf_compare(
  a : PhyloTree,
  b : PhyloTree,
  rooted : Bool,
) -> Result[RFComparisonReport, PhyloError] {
  if rooted && (a.rooting != Rooted || b.rooting != Rooted) {
    return Err(RootedTreeRequired)
  }
  let ta = a.taxa()
  let tb = b.taxa()
  if ta != tb {
    return Err(
      TaxaSetMismatch(
        ta.filter(x => !tb.contains(x)),
        tb.filter(x => !ta.contains(x)),
      ),
    )
  }
  let sa = split_sets(a, rooted)
  let sb = split_sets(b, rooted)
  let left = sa.filter(x => !sb.contains(x))
  let right = sb.filter(x => !sa.contains(x))
  Ok({
    mode: if rooted {
      Rooted
    } else {
      Unrooted
    },
    taxa: ta,
    shared: sa.filter(x => sb.contains(x)),
    only_left: left,
    only_right: right,
    distance: left.length() + right.length(),
  })
}

///|
pub fn PhyloTree::rf_distance_rooted(
  self : PhyloTree,
  other : PhyloTree,
) -> Result[RFComparisonReport, PhyloError] {
  rf_compare(self, other, true)
}

///|
pub fn PhyloTree::rf_distance_unrooted(
  self : PhyloTree,
  other : PhyloTree,
) -> Result[RFComparisonReport, PhyloError] {
  rf_compare(self, other, false)
}

///|
pub fn PhyloTree::fitch_parsimony(
  self : PhyloTree,
  traits : Map[String, Char],
) -> Result[ParsimonyResult, PhyloError] {
  if self.rooting != Rooted {
    return Err(RootedTreeRequired)
  }
  let taxa = self.taxa()
  let missing_keys = taxa.filter(t => !traits.contains(t))
  let extra : Array[String] = []
  for key, _ in traits {
    if !taxa.contains(key) {
      extra.push(key)
    }
  }
  extra.sort_by((a, b) => a.lexical_compare(b))
  if !missing_keys.is_empty() || !extra.is_empty() {
    return Err(TraitMismatch(missing_keys, extra))
  }
  let alphabet : Array[Char] = []
  let missing : Array[String] = []
  for t in taxa {
    let c = traits[t]
    if c == '-' {
      return Err(UnsupportedTrait(t))
    }
    if c == '?' {
      missing.push(t)
    } else if !alphabet.contains(c) {
      alphabet.push(c)
    }
  }
  alphabet.sort()
  let order = traversal(self)
  for id in order {
    let count = self.arena[id].children.length()
    if count == 1 {
      return Err(UnaryNotSupported(id))
    }
    if count > 2 {
      return Err(PolytomyNotSupported(id, count))
    }
  }
  let candidates : Array[Array[Char]] = Array::makei(self.arena.length(), _ => {
    []
  })
  let mut score = 0
  for i = order.length() - 1; i >= 0; i = i - 1 {
    let id = order[i]
    let n = self.arena[id]
    if n.children.is_empty() {
      let c = traits[n.label.unwrap()]
      candidates[id] = if c == '?' { alphabet.copy() } else { [c] }
    } else {
      let a = candidates[n.children[0]]
      let b = candidates[n.children[1]]
      let common = a.filter(c => b.contains(c))
      if !common.is_empty() {
        candidates[id] = common
      } else {
        let union = a.copy()
        for c in b {
          if !union.contains(c) {
            union.push(c)
          }
        }
        union.sort()
        candidates[id] = union
        if !alphabet.is_empty() {
          score = score + 1
        }
      }
    }
  }
  let assignment : Array[Char?] = Array::make(self.arena.length(), None)
  let changed = []
  for id in order {
    let choices = candidates[id]
    let inherited = match self.arena[id].parent {
      Some(p) => assignment[p]
      None => None
    }
    assignment[id] = match inherited {
      Some(c) if choices.contains(c) => Some(c)
      _ => choices.get(0)
    }
    if self.arena[id].parent is Some(p) && assignment[p] != assignment[id] {
      changed.push((p, id))
    }
  }
  Ok({
    score,
    candidates,
    assignment,
    changed_edges: changed,
    missing_taxa: missing,
  })
}
