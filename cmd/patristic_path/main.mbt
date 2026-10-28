///|
fn input_error(code : String) -> Json {
  Json::object(Map([("ok", false.to_json()), ("error", code.to_json())]))
}

///|
fn tree_error(error : @phylo.PhyloError) -> Json {
  let code = match error {
    UnknownTaxon(_) => "unknown_taxon"
    MissingLength(_) => "missing_length"
    InvalidLength(_, _) => "invalid_length"
    NumericOverflow => "numeric_overflow"
    _ => "tree_error"
  }
  let fields = Map([
    ("ok", false.to_json()),
    ("error", code.to_json()),
    ("detail", repr(error).to_json()),
  ])
  if error is UnknownTaxon(taxon) {
    fields["taxon"] = taxon.to_json()
  }
  Json::object(fields)
}

///|
fn consume() -> Json {
  let newick = match
    (
      @env.get_env_var("PHYLO_PATH_TREE_FILE"),
      @env.get_env_var("PHYLO_PATH_TREE"),
    ) {
    (Some(_), Some(_)) => return input_error("input_source_conflict")
    (Some(""), None) => return input_error("empty_tree_file")
    (Some(path), None) =>
      match read_tree_file(path) {
        Ok(text) => text
        Err(error) => return error
      }
    (None, Some(text)) => text
    (None, None) => return input_error("missing_tree")
  }
  let from = match @env.get_env_var("PHYLO_PATH_FROM") {
    Some(taxon) => taxon
    None => return input_error("missing_from")
  }
  let to = match @env.get_env_var("PHYLO_PATH_TO") {
    Some(taxon) => taxon
    None => return input_error("missing_to")
  }
  let tree = match @phylo.PhyloTree::from_newick(newick) {
    Ok(tree) => tree
    Err(error) => return tree_error(error)
  }
  let report = match tree.patristic_path(from, to) {
    Ok(report) => report
    Err(error) => return tree_error(error)
  }
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("tree_newick", tree.to_newick().to_json()),
      ("rooting", tree.rooting().to_json()),
      ("nodes", tree.nodes().to_json()),
      ("path", report.to_json()),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
