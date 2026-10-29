///|
/// Explicit leaf-name correspondence for this copy operation. IDs address the
/// source and returned trees respectively, not a later Newick reparse.
pub(all) struct TaxonRename {
  from_taxon : String
  to_taxon : String
  source_id : Int
  target_id : Int
} derive(Debug, ToJson)

///|
pub(all) struct TaxonRenameResult {
  tree : PhyloTree
  renames : Array[TaxonRename]
}

///|
/// Copy a tree with simultaneous exact leaf renames. For `(A,B)R;`, A->B and
/// B->A succeeds; A->B alone collides with the unmentioned B. Unknown sources
/// precede empty targets, then final duplicate leaves are checked. Internal
/// labels and all graph/length/comment/rooting data stay original. Every request,
/// including identity entries, has a fresh row in source-name lexical order.
pub fn PhyloTree::rename_taxa(
  self : PhyloTree,
  names : Map[String, String],
) -> Result[TaxonRenameResult, PhyloError] {
  let keys = []
  for source, _ in names {
    keys.push(source)
  }
  keys.sort_by((a, b) => a.lexical_compare(b))
  let ids = leaf_ids(self)
  let leaves : Map[String, Int] = Map([])
  for id in ids {
    leaves[self.arena[id].label.unwrap()] = id
  }
  for source in keys {
    if !leaves.contains(source) {
      return Err(UnknownTaxon(source))
    }
  }
  for source in keys {
    if names[source].is_empty() {
      return Err(AnonymousTaxon(leaves[source]))
    }
  }
  let seen : Map[String, Bool] = Map([])
  for id in ids {
    let source = self.arena[id].label.unwrap()
    let target = match names.get(source) {
      Some(target) => target
      None => source
    }
    if seen.contains(target) {
      return Err(DuplicateTaxon(target))
    }
    seen[target] = true
  }
  let arena : Array[Node] = self.arena.map(node => {
    let label = if node.children.is_empty() {
      match names.get(node.label.unwrap()) {
        Some(target) => Some(target)
        None => node.label
      }
    } else {
      node.label
    }
    {
      parent: node.parent,
      children: node.children.copy(),
      label,
      length: node.length,
      comments: node.comments.copy(),
    }
  })
  let renames = keys.map(source => {
    from_taxon: source,
    to_taxon: names[source],
    source_id: leaves[source],
    target_id: leaves[source],
  })
  Ok({
    tree: PhyloTree::{
      arena,
      root: self.root,
      rooting: self.rooting,
      comments: self.comments.copy(),
    },
    renames,
  })
}
