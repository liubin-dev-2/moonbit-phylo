///|
fn failure(code : String, detail : String) -> Json {
  Json::object(
    Map([
      ("ok", false.to_json()),
      ("error", code.to_json()),
      ("detail", detail.to_json()),
    ]),
  )
}

///|
// Independent module: a curator can consume this complete original-tree group
// review. Each terminal is identified by the same original public node snapshot.
fn consume() -> Json {
  let text = match @env.get_env_var("PHYLO_CLADE_TREE") {
    Some(text) => text
    None => return failure("missing_tree", "PHYLO_CLADE_TREE")
  }
  let selection_text = match @env.get_env_var("PHYLO_CLADE_TAXA") {
    Some(text) => text
    None => return failure("missing_taxa", "PHYLO_CLADE_TAXA")
  }
  let tree = match @phylo.PhyloTree::from_newick(text) {
    Ok(tree) => tree
    Err(error) => return failure("parser_error", repr(error))
  }
  let value = @json.parse(selection_text) catch {
    _ => return failure("invalid_taxa_json", "PHYLO_CLADE_TAXA")
  }
  guard value is Array(items) else {
    return failure("invalid_taxa", "Expected an array of strings")
  }
  let selection = []
  for item in items {
    guard item is String(taxon) else {
      return failure("invalid_taxa", "Expected an array of strings")
    }
    selection.push(taxon)
  }
  let original = tree.nodes()
  let serialized = tree.to_newick()
  let rooting = tree.rooting()
  let source_selection = selection.copy()
  let report = match tree.rooted_clade(selection) {
    Ok(report) => report
    Err(error) => {
      guard tree.nodes() == original &&
        selection == source_selection &&
        tree.to_newick() == serialized &&
        tree.rooting() == rooting else {
        abort("Failed query changed original input")
      }
      return failure("clade_error", repr(error))
    }
  }
  let annotations = original
    .filter(node => node.children.is_empty())
    .map(node => {
      let taxon = node.label.unwrap()
      let status = if report.selected_taxa.contains(taxon) {
        "selected"
      } else if report.extra_taxa.contains(taxon) {
        "intruder"
      } else {
        "outside"
      }
      Json::object(
        Map([
          ("id", node.id.to_json()),
          ("taxon", taxon.to_json()),
          ("status", status.to_json()),
        ]),
      )
    })
  let saved_selected = report.selected_taxa.copy()
  let saved_clade = report.clade_taxa.copy()
  let saved_extra = report.extra_taxa.copy()
  let separate = tree.rooted_clade(selection).unwrap()
  separate.selected_taxa.clear()
  separate.clade_taxa.clear()
  separate.extra_taxa.push("unowned")
  guard report.selected_taxa == saved_selected &&
    report.clade_taxa == saved_clade &&
    report.extra_taxa == saved_extra &&
    tree.nodes() == original &&
    selection == source_selection &&
    tree.to_newick() == serialized &&
    tree.rooting() == rooting else {
    abort("Report aliases another report or original input")
  }
  let classification = if report.is_monophyletic {
    "complete_clade"
  } else {
    "incomplete_clade"
  }
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("root_id", tree.root_id().to_json()),
      ("rooting", rooting.to_json()),
      ("original_nodes", original.to_json()),
      ("source_newick", serialized.to_json()),
      ("report", report.to_json()),
      ("mrca_node", original[report.mrca_id].to_json()),
      ("classification", classification.to_json()),
      ("terminal_annotations", annotations.to_json()),
      ("ownership_verified", true.to_json()),
      ("source_unchanged", true.to_json()),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
