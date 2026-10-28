///|
pub(all) enum Rooting {
  Rooted
  Unrooted
  Unknown
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PhyloError {
  Syntax(Int, String)
  InvalidLength(Int, String)
  MissingLength(Int)
  DuplicateTaxon(String)
  AnonymousTaxon(Int)
  RootedTreeRequired
  RootingConflict
  PolytomyNotSupported(Int, Int)
  UnaryNotSupported(Int)
  TaxaSetMismatch(Array[String], Array[String])
  TraitMismatch(Array[String], Array[String])
  UnsupportedTrait(String)
  UnknownTaxon(String)
  EmptySelection
  DuplicateSelection(String)
  NumericOverflow
} derive(Debug, Eq)

///|
priv suberror Failure {
  Fault(PhyloError)
}

///|
struct Node {
  mut parent : Int?
  children : Array[Int]
  mut label : String?
  mut length : Double?
  comments : Array[String]
}

///|
fn new_node(parent : Int?, label : String?) -> Node {
  { parent, children: [], label, length: None, comments: [], }
}

///|
pub struct PhyloTree {
  arena : Array[Node]
  root : Int
  rooting : Rooting
  comments : Array[String]
}

///|
pub(all) struct NodeRecord {
  id : Int
  parent : Int?
  children : Array[Int]
  label : String?
  length : Double?
  comments : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RFComparisonReport {
  mode : Rooting
  taxa : Array[String]
  shared : Array[Array[String]]
  only_left : Array[Array[String]]
  only_right : Array[Array[String]]
  distance : Int
} derive(Debug, ToJson)

///|
pub(all) struct ParsimonyResult {
  score : Int
  candidates : Array[Array[Char]]
  assignment : Array[Char?]
  changed_edges : Array[(Int, Int)]
  missing_taxa : Array[String]
} derive(Debug, ToJson)

///|
pub(all) struct DistanceMatrix {
  taxa : Array[String]
  values : Array[Array[Double]]
} derive(Debug, ToJson)

///|
pub(all) struct TransformWitness {
  old_to_new : Array[Int?]
  retained_taxa : Array[String]
  edge_paths : Array[Array[Int]]
  diameter_endpoints : Array[String]
  diameter : Double?
  split_edge : Array[Int]
  offset : Double?
} derive(Debug, ToJson)

///|
pub(all) struct TransformResult {
  tree : PhyloTree
  witness : TransformWitness
}

///|
pub fn PhyloTree::root_id(self : PhyloTree) -> Int {
  self.root
}

///|
pub fn PhyloTree::rooting(self : PhyloTree) -> Rooting {
  self.rooting
}

///|
pub fn PhyloTree::nodes(self : PhyloTree) -> Array[NodeRecord] {
  self.arena.mapi((id, n) => {
    id,
    parent: n.parent,
    children: n.children.copy(),
    label: n.label,
    length: n.length,
    comments: n.comments.copy(),
  })
}

///|
pub fn PhyloTree::tree_comments(self : PhyloTree) -> Array[String] {
  self.comments.copy()
}

///|
fn traversal(tree : PhyloTree) -> Array[Int] {
  let order = []
  let stack = [tree.root]
  while stack.length() > 0 {
    let n = stack.pop().unwrap()
    order.push(n)
    for i = tree.arena[n].children.length() - 1; i >= 0; i = i - 1 {
      stack.push(tree.arena[n].children[i])
    }
  }
  order
}

///|
fn leaf_ids(tree : PhyloTree) -> Array[Int] {
  let ids = traversal(tree).filter(n => tree.arena[n].children.is_empty())
  ids.sort_by((a, b) => {
    tree.arena[a].label.unwrap().lexical_compare(tree.arena[b].label.unwrap())
  })
  ids
}

///|
pub fn PhyloTree::taxa(self : PhyloTree) -> Array[String] {
  leaf_ids(self).map(n => self.arena[n].label.unwrap())
}

///|
fn compare_labels(a : Array[String], b : Array[String]) -> Int {
  for i = 0; i < a.length() && i < b.length(); i = i + 1 {
    let order = a[i].lexical_compare(b[i])
    if order != 0 {
      return order
    }
  }
  a.length().compare(b.length())
}
