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
fn domain_error(
  error : @phylo.PhyloError,
  nodes : Array[@phylo.NodeRecord],
) -> Json {
  let fields = Map([
    ("ok", false.to_json()),
    ("detail", repr(error).to_json()),
    ("original_nodes", nodes.to_json()),
    ("source_unchanged", true.to_json()),
  ])
  match error {
    @phylo.UnknownTaxon(taxon) => {
      fields["error"] = "unknown_source".to_json()
      fields["taxon"] = taxon.to_json()
    }
    @phylo.AnonymousTaxon(id) => {
      fields["error"] = "empty_target".to_json()
      fields["node_id"] = id.to_json()
    }
    @phylo.DuplicateTaxon(taxon) => {
      fields["error"] = "duplicate_taxon".to_json()
      fields["taxon"] = taxon.to_json()
    }
    _ => fields["error"] = "rename_error".to_json()
  }
  Json::object(fields)
}

///|
fn consume() -> Json {
  let text = match @env.get_env_var("PHYLO_RENAME_TREE") {
    Some(text) => text
    None => return failure("missing_tree", "PHYLO_RENAME_TREE")
  }
  let map_text = match @env.get_env_var("PHYLO_RENAME_MAP") {
    Some(text) => text
    None => return failure("missing_renames", "PHYLO_RENAME_MAP")
  }
  let tree = match @phylo.PhyloTree::from_newick(text) {
    Ok(tree) => tree
    Err(error) => return failure("parser_error", repr(error))
  }
  let value = @json.parse(map_text) catch {
    _ => return failure("invalid_renames_json", "PHYLO_RENAME_MAP")
  }
  guard value is Object(fields) else {
    return failure("invalid_renames", "Expected a JSON object")
  }
  let keys = []
  for key, _ in fields {
    keys.push(key)
  }
  keys.sort_by((a, b) => a.lexical_compare(b))
  let names : Map[String, String] = Map([])
  for key in keys {
    guard fields[key] is String(target) else {
      return Json::object(
        Map([
          ("ok", false.to_json()),
          ("error", "invalid_target".to_json()),
          ("taxon", key.to_json()),
        ]),
      )
    }
    names[key] = target
  }
  let original = tree.nodes()
  let source_text = tree.to_newick()
  let source_comments = tree.tree_comments()
  let rooting = tree.rooting()
  let name_snapshot = names.to_json().stringify()
  let result = tree.rename_taxa(names)
  guard tree.nodes() == original &&
    tree.to_newick() == source_text &&
    tree.tree_comments() == source_comments &&
    tree.rooting() == rooting &&
    names.to_json().stringify() == name_snapshot else {
    abort("Rename mutated original input")
  }
  let report = match result {
    Ok(report) => report
    Err(error) => return domain_error(error, original)
  }
  let renamed_nodes = report.tree.nodes()
  let renamed_text = report.tree.to_newick()
  let rename_json = report.renames.to_json()
  // Only new result/caller ownership is exercised, not an old getter test suite.
  names.clear()
  report.renames.clear()
  guard report.tree.nodes() == renamed_nodes &&
    report.tree.to_newick() == renamed_text &&
    tree.nodes() == original else {
    abort("Rename result aliases caller input")
  }
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("original_nodes", original.to_json()),
      ("source_root_id", tree.root_id().to_json()),
      ("source_newick", source_text.to_json()),
      ("source_tree_comments", source_comments.to_json()),
      ("rooting", rooting.to_json()),
      ("renamed_nodes", renamed_nodes.to_json()),
      ("renamed_root_id", report.tree.root_id().to_json()),
      ("renamed_rooting", report.tree.rooting().to_json()),
      ("renamed_newick", renamed_text.to_json()),
      ("renamed_tree_comments", report.tree.tree_comments().to_json()),
      ("renames", rename_json),
      ("source_unchanged", true.to_json()),
      ("ownership_verified", true.to_json()),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
