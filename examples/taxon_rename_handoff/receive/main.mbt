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
fn consume() -> Json {
  let text = match @env.get_env_var("PHYLO_RENAMED_TREE") {
    Some(text) => text
    None => return failure("missing_tree", "PHYLO_RENAMED_TREE")
  }
  let tree = match @phylo.PhyloTree::from_newick(text) {
    Ok(tree) => tree
    Err(error) => return failure("parser_error", repr(error))
  }
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("nodes", tree.nodes().to_json()),
      ("root_id", tree.root_id().to_json()),
      ("rooting", tree.rooting().to_json()),
      ("tree_comments", tree.tree_comments().to_json()),
      ("taxa", tree.taxa().to_json()),
      ("tree_newick", tree.to_newick().to_json()),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
