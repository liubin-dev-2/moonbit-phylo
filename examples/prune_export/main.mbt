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
  let text = match @env.get_env_var("PHYLO_PRUNE_TREE") {
    Some(text) => text
    None => return failure("missing_tree", "PHYLO_PRUNE_TREE")
  }
  let retain_text = match @env.get_env_var("PHYLO_PRUNE_RETAIN") {
    Some(text) => text
    None => return failure("missing_retain", "PHYLO_PRUNE_RETAIN")
  }
  let tree = match @phylo.PhyloTree::from_newick(text) {
    Ok(tree) => tree
    Err(error) => return failure("parser_error", repr(error))
  }
  let value = @json.parse(retain_text) catch {
    _ => return failure("invalid_retain_json", "PHYLO_PRUNE_RETAIN")
  }
  guard value is Array(items) else {
    return failure("invalid_retain", "Expected an array of exact leaf names")
  }
  let retain = []
  for item in items {
    guard item is String(taxon) else {
      return failure("invalid_retain", "Expected an array of exact leaf names")
    }
    retain.push(taxon)
  }
  let original = tree.nodes()
  let original_text = tree.to_newick()
  let original_retain = retain.copy()
  let outcome = tree.prune(retain)
  guard tree.nodes() == original &&
    tree.to_newick() == original_text &&
    retain == original_retain else {
    abort("Pruning request changed original input")
  }
  let result = match outcome {
    Ok(result) => result
    Err(error) =>
      return Json::object(
        Map([
          ("ok", false.to_json()),
          ("error", "prune_error".to_json()),
          ("detail", repr(error).to_json()),
          ("original_nodes", original.to_json()),
          ("requested_taxa", original_retain.to_json()),
          ("source_unchanged", true.to_json()),
        ]),
      )
  }
  let nodes = result.tree.nodes()
  let old_by_target : Map[Int, Int] = Map([])
  for old, target in result.witness.old_to_new {
    if target is Some(id) {
      old_by_target[id] = old
    }
  }
  let lineages : Array[Json] = []
  for node in nodes {
    if node.parent is Some(parent) {
      let path = result.witness.edge_paths[node.id]
      let vertices = [old_by_target[parent]]
      vertices.append(path)
      lineages.push(
        Json::object(
          Map([
            ("target_parent_id", parent.to_json()),
            ("target_child_id", node.id.to_json()),
            ("source_node_ids", vertices.to_json()),
            ("source_edge_ids", path.to_json()),
          ]),
        ),
      )
    }
  }
  let history = result.witness.edge_paths[result.tree.root_id()]
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("requested_taxa", original_retain.to_json()),
      ("original_nodes", original.to_json()),
      ("source_root_id", tree.root_id().to_json()),
      ("source_rooting", tree.rooting().to_json()),
      ("source_tree_comments", tree.tree_comments().to_json()),
      ("source_newick", original_text.to_json()),
      ("pruned_nodes", nodes.to_json()),
      ("pruned_root_id", result.tree.root_id().to_json()),
      ("pruned_rooting", result.tree.rooting().to_json()),
      ("pruned_tree_comments", result.tree.tree_comments().to_json()),
      ("pruned_newick", result.tree.to_newick().to_json()),
      ("witness", result.witness.to_json()),
      ("edge_lineage", lineages.to_json()),
      ("root_history", history.to_json()),
      ("root_history_nodes", history.map(id => original[id]).to_json()),
      ("source_unchanged", true.to_json()),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
