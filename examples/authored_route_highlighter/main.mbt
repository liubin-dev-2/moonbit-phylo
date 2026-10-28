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
fn weighted_value(value : Result[Double, @phylo.PhyloError]) -> Json {
  match value {
    Ok(distance) =>
      Json::object(
        Map([("ok", true.to_json()), ("distance", distance.to_json())]),
      )
    Err(error) => failure("weighted_error", repr(error))
  }
}

///|
fn style_index(index : Int?) -> Json {
  match index {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
// This standalone module imports only public API. A renderer can apply these
// highlight indices to its own original node/child-edge ID keyed style tables.
fn consume() -> Json {
  let text = match @env.get_env_var("PHYLO_ROUTE_TREE") {
    Some(text) => text
    None => return failure("missing_tree", "PHYLO_ROUTE_TREE")
  }
  let from = match @env.get_env_var("PHYLO_ROUTE_FROM") {
    Some(name) => name
    None => return failure("missing_from", "PHYLO_ROUTE_FROM")
  }
  let to = match @env.get_env_var("PHYLO_ROUTE_TO") {
    Some(name) => name
    None => return failure("missing_to", "PHYLO_ROUTE_TO")
  }
  let tree = match @phylo.PhyloTree::from_newick(text) {
    Ok(tree) => tree
    Err(error) => return failure("parser_error", repr(error))
  }
  let original = tree.nodes()
  let serialized = tree.to_newick()
  let rooting = tree.rooting()
  let route = match tree.authored_leaf_route(from, to) {
    Ok(report) => report
    Err(@phylo.UnknownTaxon(taxon)) => {
      guard original == tree.nodes() else { abort("Query changed original") }
      return Json::object(
        Map([
          ("ok", false.to_json()),
          ("error", "unknown_taxon".to_json()),
          ("taxon", taxon.to_json()),
        ]),
      )
    }
    Err(error) => return failure("route_error", repr(error))
  }
  let node_indices : Map[Int, Int] = Map([])
  let edge_indices : Map[Int, Int] = Map([])
  for order, id in route.node_ids {
    node_indices[id] = order
  }
  for order, id in route.edge_ids {
    edge_indices[id] = order
  }
  let node_styles = original.map(node => {
    Json::object(
      Map([
        ("id", node.id.to_json()),
        ("highlighted", node_indices.contains(node.id).to_json()),
        ("route_index", style_index(node_indices.get(node.id))),
      ]),
    )
  })
  let edge_styles = original
    .filter(node => node.parent is Some(_))
    .map(node => {
      Json::object(
        Map([
          ("child_id", node.id.to_json()),
          ("parent_id", node.parent.unwrap().to_json()),
          ("highlighted", edge_indices.contains(node.id).to_json()),
          ("route_index", style_index(edge_indices.get(node.id))),
        ]),
      )
    })
  // Only new route ownership is exercised: no old getter-copy test framework.
  let saved_nodes = route.node_ids.copy()
  let saved_edges = route.edge_ids.copy()
  let separate = tree.authored_leaf_route(from, to).unwrap()
  separate.node_ids.clear()
  separate.edge_ids.push(-1)
  guard route.node_ids == saved_nodes &&
    route.edge_ids == saved_edges &&
    tree.nodes() == original &&
    tree.to_newick() == serialized &&
    tree.rooting() == rooting else {
    abort("Route arrays alias source or another report")
  }
  let weighted = tree.patristic_path(from, to)
  let distance = tree.patristic_distance(from, to)
  guard weighted.map(report => report.distance) == distance else {
    abort("Weighted contracts differ")
  }
  let path_json = match weighted {
    Ok(report) => report.to_json()
    Err(error) => failure("weighted_error", repr(error))
  }
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("rooting", rooting.to_json()),
      ("original_nodes", original.to_json()),
      ("source_newick", serialized.to_json()),
      ("route", route.to_json()),
      ("node_styles", node_styles.to_json()),
      ("edge_styles", edge_styles.to_json()),
      ("ownership_verified", true.to_json()),
      ("source_unchanged", true.to_json()),
      ("weighted_distance", weighted_value(distance)),
      ("weighted_path", path_json),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
