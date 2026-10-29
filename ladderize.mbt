///|
/// Return an independent tree with each sibling list ordered by descendant leaf
/// count (ascending by default, descending with reverse=true). Equal counts keep
/// their input order in either direction. Only child order changes: IDs, parents,
/// rooting, labels, optional lengths and comments stay with the original nodes.
/// This is presentation order, not a canonical tree or a scientific distance.
pub fn PhyloTree::ladderize(
  self : PhyloTree,
  reverse? : Bool = false,
) -> PhyloTree {
  let counts = Array::make(self.arena.length(), 0)
  let order = traversal(self)
  for k = order.length() - 1; k >= 0; k = k - 1 {
    let id = order[k]
    let node = self.arena[id]
    if node.children.is_empty() {
      counts[id] = 1
    } else {
      for child in node.children {
        counts[id] = counts[id] + counts[child]
      }
    }
  }
  let arena : Array[Node] = self.arena.map(node => {
    // Explicit source ranks make ties stable independently of sort stability.
    let ranked = node.children.mapi((rank, child) => (rank, child))
    ranked.sort_by((a, b) => {
      let (rank_a, id_a) = a
      let (rank_b, id_b) = b
      let compared = counts[id_a].compare(counts[id_b])
      if compared == 0 {
        rank_a.compare(rank_b)
      } else if reverse {
        -compared
      } else {
        compared
      }
    })
    {
      parent: node.parent,
      children: ranked.map(pair => {
        let (_, id) = pair
        id
      }),
      label: node.label,
      length: node.length,
      comments: node.comments.copy(),
    }
  })
  {
    arena,
    root: self.root,
    rooting: self.rooting,
    comments: self.comments.copy(),
  }
}
