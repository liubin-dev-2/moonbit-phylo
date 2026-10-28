///|
pub(all) struct FaithPDGreedyStep {
  taxon : String
  edge_ids : Array[Int]
  gain : Double
} derive(Debug, ToJson)

///|
pub(all) struct FaithPDGreedyReport {
  baseline_taxa : Array[String]
  candidate_taxa : Array[String]
  limit : UInt
  added_taxa : Array[String]
  selected_taxa : Array[String]
  root_id : Int
  edge_ids : Array[Int]
  gain : Double
  steps : Array[FaithPDGreedyStep]
} derive(Debug, ToJson)

///|
/// Add up to limit eligible taxa by exact marginal rooted PD, recomputing after
/// each choice. True ties use lexical order; zero-gain choices are retained.
pub fn PhyloTree::faith_pd_greedy(
  self : PhyloTree,
  baseline : Array[String],
  candidates : Array[String],
  limit : UInt,
) -> Result[FaithPDGreedyReport, PhyloError] {
  if self.rooting != Rooted {
    return Err(RootedTreeRequired)
  }
  try {
    check_lengths(self)
    let (baseline_taxa, covered) = pd_selection(self, baseline)
    let (requested, _) = pd_selection(self, candidates)
    let baseline_set : Map[String, Bool] = Map([])
    for taxon in baseline_taxa {
      baseline_set[taxon] = true
    }
    let candidate_taxa = requested.filter(taxon => !baseline_set.contains(taxon))
    let leaves : Map[String, Int] = Map([])
    for id, node in self.arena {
      if node.children.is_empty() {
        leaves[node.label.unwrap()] = id
      }
    }
    let chosen = Array::make(candidate_taxa.length(), false)
    let new_edges = Array::make(self.arena.length(), false)
    let added_taxa = []
    let steps = []
    let mut total = @bigint.BigInt::from_int(0)
    for count = 0U; count < limit; count = count + 1U {
      let mut best = -1
      let mut best_units = @bigint.BigInt::from_int(0)
      let mut best_edges : Array[Int] = []
      for i, taxon in candidate_taxa {
        if chosen[i] {
          continue
        }
        let mut node = leaves[taxon]
        let mut units = @bigint.BigInt::from_int(0)
        let edges = []
        while node != self.root && !covered[node] {
          edges.push(node)
          units = units + length_units(self.arena[node].length.unwrap())
          node = self.arena[node].parent.unwrap()
        }
        // candidate_taxa is lexical; equal exact sums keep the first taxon.
        if best < 0 || units > best_units {
          best = i
          best_units = units
          best_edges = edges
        }
      }
      if best < 0 {
        break
      }
      let gain = rounded_length(best_units)
      if gain.is_inf() {
        raise Fault(NumericOverflow)
      }
      best_edges.sort_by((a, b) => a.compare(b))
      for id in best_edges {
        covered[id] = true
        new_edges[id] = true
      }
      chosen[best] = true
      let taxon = candidate_taxa[best]
      added_taxa.push(taxon)
      steps.push({ taxon, edge_ids: best_edges, gain, })
      total = total + best_units
    }
    let gain = rounded_length(total)
    if gain.is_inf() {
      raise Fault(NumericOverflow)
    }
    let selected_taxa = baseline_taxa.copy()
    selected_taxa.append(added_taxa)
    selected_taxa.sort_by((a, b) => a.lexical_compare(b))
    let edge_ids = []
    for id, take in new_edges {
      if take {
        edge_ids.push(id)
      }
    }
    Ok({
      baseline_taxa,
      candidate_taxa,
      limit,
      added_taxa,
      selected_taxa,
      root_id: self.root,
      edge_ids,
      gain,
      steps,
    })
  } catch {
    Fault(error) => Err(error)
  }
}
