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
fn terminal_rows(nodes : Array[@phylo.NodeRecord], root : Int) -> Json {
  let rows : Array[Json] = []
  let stack = [root]
  while !stack.is_empty() {
    let id = stack.pop().unwrap()
    let node = nodes[id]
    if node.children.is_empty() {
      rows.push(
        Json::object(
          Map([
            ("row", rows.length().to_json()),
            ("id", id.to_json()),
            ("taxon", node.label.unwrap().to_json()),
          ]),
        ),
      )
    } else {
      for k = node.children.length() - 1; k >= 0; k = k - 1 {
        stack.push(node.children[k])
      }
    }
  }
  rows.to_json()
}

///|
fn consume() -> Json {
  let requested = @env.get_env_var("PHYLO_LADDER_ORDER")
  let order = match requested {
    None | Some("ascending") => "ascending"
    Some("descending") => "descending"
    Some(_) =>
      return failure("invalid_order", "Expected ascending or descending")
  }
  let text = match @env.get_env_var("PHYLO_LADDER_TREE") {
    Some(text) => text
    None => return failure("missing_tree", "PHYLO_LADDER_TREE")
  }
  let tree = match @phylo.PhyloTree::from_newick(text) {
    Ok(tree) => tree
    Err(error) => return failure("parser_error", repr(error))
  }
  let original = tree.nodes()
  let original_text = tree.to_newick()
  let ordered = if requested is None {
    tree.ladderize()
  } else {
    tree.ladderize(reverse=order == "descending")
  }
  let nodes = ordered.nodes()
  let exported = ordered.to_newick()
  guard original == tree.nodes() && original_text == tree.to_newick() else {
    abort("Ladderization changed source tree")
  }
  guard ordered.ladderize(reverse=order == "descending").nodes() == nodes else {
    abort("Ladderization changed on repetition")
  }
  let received = @phylo.PhyloTree::from_newick(exported).unwrap()
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("order", order.to_json()),
      ("original_nodes", original.to_json()),
      ("source_root_id", tree.root_id().to_json()),
      ("source_newick", original_text.to_json()),
      ("source_rooting", tree.rooting().to_json()),
      ("source_tree_comments", tree.tree_comments().to_json()),
      ("ordered_nodes", nodes.to_json()),
      ("ordered_root_id", ordered.root_id().to_json()),
      ("ordered_newick", exported.to_json()),
      ("ordered_rooting", ordered.rooting().to_json()),
      ("ordered_tree_comments", ordered.tree_comments().to_json()),
      ("terminal_rows", terminal_rows(nodes, ordered.root_id())),
      ("reparsed_nodes", received.nodes().to_json()),
      ("reparsed_root_id", received.root_id().to_json()),
      ("reparsed_rooting", received.rooting().to_json()),
      ("reparsed_tree_comments", received.tree_comments().to_json()),
      ("reparsed_newick", received.to_newick().to_json()),
      ("source_unchanged", true.to_json()),
      ("idempotent", true.to_json()),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
