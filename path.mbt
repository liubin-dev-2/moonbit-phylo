///|
/// An ordered leaf-to-leaf witness in one tree instance. An edge ID is the
/// child NodeId of that edge, even when the path traverses it towards its parent.
pub(all) struct PatristicPathReport {
  from_taxon : String
  to_taxon : String
  node_ids : Array[Int]
  edge_ids : Array[Int]
  distance : Double
} derive(Debug, ToJson)

///|
/// An ordered route on the exact authored graph, independent of branch lengths.
/// Count refers only to this representation, not a topology or distance invariant.
pub(all) struct AuthoredLeafRouteReport {
  from_taxon : String
  to_taxon : String
  node_ids : Array[Int]
  edge_ids : Array[Int]
  authored_edge_count : Int
} derive(Debug, ToJson)

///|
fn PhyloTree::authored_route_geometry(
  self : PhyloTree,
  from : String,
  to : String,
) -> Result[AuthoredLeafRouteReport, PhyloError] {
  let mut a = -1
  let mut b = -1
  for id in leaf_ids(self) {
    if self.arena[id].label == Some(from) {
      a = id
    }
    if self.arena[id].label == Some(to) {
      b = id
    }
  }
  if a < 0 {
    return Err(UnknownTaxon(from))
  }
  if b < 0 {
    return Err(UnknownTaxon(to))
  }
  let ancestors = Array::make(self.arena.length(), false)
  let mut current = a
  while true {
    ancestors[current] = true
    match self.arena[current].parent {
      Some(parent) => current = parent
      None => break
    }
  }
  let tail = []
  let mut common = b
  while !ancestors[common] {
    tail.push(common)
    common = self.arena[common].parent.unwrap()
  }
  let node_ids = []
  current = a
  while true {
    node_ids.push(current)
    if current == common {
      break
    }
    current = self.arena[current].parent.unwrap()
  }
  for i = tail.length() - 1; i >= 0; i = i - 1 {
    node_ids.push(tail[i])
  }
  let edge_ids = Array::makei(node_ids.length() - 1, i => {
    let start = node_ids[i]
    let finish = node_ids[i + 1]
    if self.arena[start].parent == Some(finish) {
      start
    } else {
      finish
    }
  })
  Ok({
    from_taxon: from,
    to_taxon: to,
    node_ids,
    edge_ids,
    authored_edge_count: edge_ids.length(),
  })
}

///|
/// Return the original leaf-to-leaf route without reading or filling lengths.
/// Both endpoints and all unary/degree2/root-seed nodes remain. An edge ID is
/// always the original child NodeId; a root stem is not a parent edge. Self
/// returns one node and no edges. Unknown from is reported before unknown to.
/// Arrays are fresh; IDs belong only to this tree's nodes(), not another parse,
/// transform or layout. The authored edge count is not subdivision/root invariant.
pub fn PhyloTree::authored_leaf_route(
  self : PhyloTree,
  from : String,
  to : String,
) -> Result[AuthoredLeafRouteReport, PhyloError] {
  self.authored_route_geometry(from, to)
}

///|
/// Return both endpoint nodes and every intervening edge in traversal order.
/// Uses exactly patristic_distance's validation, one-round sum and errors.
/// Root stems are excluded. A self-pair has one node and no edges. IDs refer to
/// self.nodes() only; reparsing or transforming a tree can assign different IDs.
pub fn PhyloTree::patristic_path(
  self : PhyloTree,
  from : String,
  to : String,
) -> Result[PatristicPathReport, PhyloError] {
  // Retain weighted preflight before the shared length-independent geometry.
  let distance = match self.patristic_distance(from, to) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match self.authored_route_geometry(from, to) {
    Err(error) => Err(error)
    Ok(route) =>
      Ok({
        from_taxon: from,
        to_taxon: to,
        node_ids: route.node_ids,
        edge_ids: route.edge_ids,
        distance,
      })
  }
}
