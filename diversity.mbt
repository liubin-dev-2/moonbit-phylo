///|
/// Presence-only rooted Faith PD. Edge IDs identify child nodes in the input tree;
/// each selected root-to-tip branch contributes once, excluding the root stem.
pub(all) struct FaithPDReport {
  selected_taxa : Array[String]
  root_id : Int
  edge_ids : Array[Int]
  total_length : Double
} derive(Debug, ToJson)

///|
/// Require explicit Rooted and complete nonroot lengths. Empty presence is valid;
/// unknown or repeated taxa are errors. Does not modify the input tree.
pub fn PhyloTree::faith_pd(
  self : PhyloTree,
  present : Array[String],
) -> Result[FaithPDReport, PhyloError] {
  if self.rooting != Rooted {
    return Err(RootedTreeRequired)
  }
  try {
    check_lengths(self)
    let (selected_taxa, included) = pd_selection(self, present)
    let edge_ids = []
    let mut total = @bigint.BigInt::from_int(0)
    for id, take in included {
      if take {
        edge_ids.push(id)
        total = total + length_units(self.arena[id].length.unwrap())
      }
    }
    let total_length = rounded_length(total)
    if total_length.is_inf() {
      raise Fault(NumericOverflow)
    }
    Ok({ selected_taxa, root_id: self.root, edge_ids, total_length, })
  } catch {
    Fault(error) => Err(error)
  }
}

///|
// Shared selection validation and root-path membership; public entry points
// validate rooting and complete lengths before calling.
fn pd_selection(
  tree : PhyloTree,
  present : Array[String],
) -> (Array[String], Array[Bool]) raise Failure {
  let leaves : Map[String, Int] = Map([])
  for id, node in tree.arena {
    if node.children.is_empty() {
      leaves[node.label.unwrap()] = id
    }
  }
  let selected = present.copy()
  let seen : Map[String, Bool] = Map([])
  let included = Array::make(tree.arena.length(), false)
  for taxon in selected {
    guard leaves.get(taxon) is Some(leaf) else {
      raise Fault(UnknownTaxon(taxon))
    }
    if seen.contains(taxon) {
      raise Fault(DuplicateSelection(taxon))
    }
    seen[taxon] = true
    let mut node = leaf
    while node != tree.root && !included[node] {
      included[node] = true
      node = tree.arena[node].parent.unwrap()
    }
  }
  selected.sort_by((a, b) => a.lexical_compare(b))
  (selected, included)
}
