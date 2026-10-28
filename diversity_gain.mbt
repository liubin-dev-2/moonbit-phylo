///|
/// Additional rooted Faith PD coverage relative to a baseline. Edge IDs belong
/// to the input tree and identify newly covered child-to-parent branches only.
pub(all) struct FaithPDGainReport {
  baseline_taxa : Array[String]
  added_taxa : Array[String]
  root_id : Int
  edge_ids : Array[Int]
  gain : Double
} derive(Debug, ToJson)

///|
/// Sum newly covered branches directly, avoiding subtraction of rounded totals.
/// Overlap across the two arrays is allowed; duplicates within either are errors.
pub fn PhyloTree::faith_pd_gain(
  self : PhyloTree,
  baseline : Array[String],
  additions : Array[String],
) -> Result[FaithPDGainReport, PhyloError] {
  if self.rooting != Rooted {
    return Err(RootedTreeRequired)
  }
  try {
    check_lengths(self)
    let (baseline_taxa, covered) = pd_selection(self, baseline)
    let (requested, candidate_edges) = pd_selection(self, additions)
    let baseline_set : Map[String, Bool] = Map([])
    for taxon in baseline_taxa {
      baseline_set[taxon] = true
    }
    let added_taxa = requested.filter(taxon => !baseline_set.contains(taxon))
    let edge_ids = []
    let mut total = @bigint.BigInt::from_int(0)
    for id, take in candidate_edges {
      if take && !covered[id] {
        edge_ids.push(id)
        total = total + length_units(self.arena[id].length.unwrap())
      }
    }
    let gain = rounded_length(total)
    if gain.is_inf() {
      raise Fault(NumericOverflow)
    }
    Ok({ baseline_taxa, added_taxa, root_id: self.root, edge_ids, gain, })
  } catch {
    Fault(error) => Err(error)
  }
}
