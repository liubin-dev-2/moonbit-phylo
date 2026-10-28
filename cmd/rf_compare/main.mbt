///|
fn input_error(code : String) -> Json {
  Json::object(Map([("ok", false.to_json()), ("error", code.to_json())]))
}

///|
fn tree_error(input : String, error : @phylo.PhyloError) -> Json {
  Json::object(
    Map([
      ("ok", false.to_json()),
      ("error", "tree_error".to_json()),
      ("input", input.to_json()),
      ("detail", repr(error).to_json()),
    ]),
  )
}

///|
fn compare_error(error : @phylo.PhyloError) -> Json {
  match error {
    RootedTreeRequired => input_error("rooted_tree_required")
    TaxaSetMismatch(left, right) =>
      Json::object(
        Map([
          ("ok", false.to_json()),
          ("error", "taxa_set_mismatch".to_json()),
          ("only_left_taxa", left.to_json()),
          ("only_right_taxa", right.to_json()),
        ]),
      )
    _ => tree_error("comparison", error)
  }
}

///|
fn consume() -> Json {
  let mode = match @env.get_env_var("PHYLO_RF_MODE") {
    Some("rooted") => true
    Some("unrooted") => false
    Some(_) => return input_error("invalid_mode")
    None => return input_error("missing_mode")
  }
  let left = match @env.get_env_var("PHYLO_RF_LEFT") {
    Some(text) => text
    None => return input_error("missing_left")
  }
  let right = match @env.get_env_var("PHYLO_RF_RIGHT") {
    Some(text) => text
    None => return input_error("missing_right")
  }
  let a = match @phylo.PhyloTree::from_newick(left) {
    Ok(tree) => tree
    Err(error) => return tree_error("left", error)
  }
  let b = match @phylo.PhyloTree::from_newick(right) {
    Ok(tree) => tree
    Err(error) => return tree_error("right", error)
  }
  let result = if mode {
    a.rf_distance_rooted(b)
  } else {
    a.rf_distance_unrooted(b)
  }
  let report = match result {
    Ok(report) => report
    Err(error) => return compare_error(error)
  }
  guard report.to_json() is Object(fields) else {
    abort("RFComparisonReport must be an object")
  }
  fields["ok"] = true.to_json()
  Json::object(fields)
}

///|
fn main {
  println(consume().stringify())
}
