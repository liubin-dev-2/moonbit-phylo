///|
/// Original rooted clade containing a nonempty exact leaf selection. The MRCA
/// ID belongs only to this tree; extra_taxa explains an incomplete clade.
pub(all) struct RootedCladeReport {
  selected_taxa : Array[String]
  mrca_id : Int
  clade_taxa : Array[String]
  extra_taxa : Array[String]
  is_monophyletic : Bool
} derive(Debug, ToJson)

///|
/// Review a leaf group against its complete original rooted clade. For
/// `[&R]((A,B)AB,C)R;`, A/B is complete at AB; A/C has B as an extra taxon at R.
/// Explicit Rooted is required first, followed by a nonempty selection. Unknown
/// and duplicate leaves fail in input order. Branch lengths are never read.
/// A singleton's MRCA is that leaf, including below unary ancestors. All name
/// arrays are fresh and sorted using the existing exact UTF-16 lexical order.
pub fn PhyloTree::rooted_clade(
  self : PhyloTree,
  present : Array[String],
) -> Result[RootedCladeReport, PhyloError] {
  if self.rooting != Rooted {
    return Err(RootedTreeRequired)
  }
  if present.is_empty() {
    return Err(EmptySelection)
  }
  let leaves : Map[String, Int] = Map([])
  for id in leaf_ids(self) {
    leaves[self.arena[id].label.unwrap()] = id
  }
  let selected_ids = []
  let seen : Map[String, Bool] = Map([])
  for taxon in present {
    guard leaves.get(taxon) is Some(id) else { return Err(UnknownTaxon(taxon)) }
    if seen.contains(taxon) {
      return Err(DuplicateSelection(taxon))
    }
    seen[taxon] = true
    selected_ids.push(id)
  }
  // Count distinct selected descendants along their original parent paths.
  let coverage = Array::make(self.arena.length(), 0)
  for leaf in selected_ids {
    let mut id = leaf
    while id != self.root {
      coverage[id] = coverage[id] + 1
      id = self.arena[id].parent.unwrap()
    }
    coverage[self.root] = coverage[self.root] + 1
  }
  let mut mrca = selected_ids[0]
  while coverage[mrca] != selected_ids.length() {
    mrca = self.arena[mrca].parent.unwrap()
  }
  let clade_taxa = []
  let stack = [mrca]
  while !stack.is_empty() {
    let node = self.arena[stack.pop().unwrap()]
    if node.children.is_empty() {
      clade_taxa.push(node.label.unwrap())
    } else {
      stack.append(node.children)
    }
  }
  clade_taxa.sort_by((a, b) => a.lexical_compare(b))
  let extra_taxa = clade_taxa.filter(taxon => !seen.contains(taxon))
  let selected_taxa = present.copy()
  selected_taxa.sort_by((a, b) => a.lexical_compare(b))
  Ok({
    selected_taxa,
    mrca_id: mrca,
    clade_taxa,
    extra_taxa,
    is_monophyletic: extra_taxa.is_empty(),
  })
}
