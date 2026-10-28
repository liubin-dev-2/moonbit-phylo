///|
test "authored route uses original hand roles without requiring lengths" {
  let tree = @phylo.PhyloTree::from_newick("[&U](((A)U,B)X,(C,D)Y)R;").unwrap()
  let before = tree.nodes()
  let report = tree.authored_leaf_route("A", "C").unwrap()
  assert_eq(report.node_ids.map(i => before[i].label.unwrap()), [
    "A", "U", "X", "R", "Y", "C",
  ])
  assert_eq(report.edge_ids.map(i => before[i].label.unwrap()), [
    "A", "U", "X", "Y", "C",
  ])
  assert_eq(report.authored_edge_count, 5)
  let reverse = tree.authored_leaf_route("C", "A").unwrap()
  assert_eq(reverse.node_ids.map(i => before[i].label.unwrap()), [
    "C", "Y", "R", "X", "U", "A",
  ])
  assert_eq(reverse.edge_ids.map(i => before[i].label.unwrap()), [
    "C", "Y", "X", "U", "A",
  ])
  let same = tree.authored_leaf_route("B", "B").unwrap()
  assert_eq(same.node_ids.map(i => before[i].label.unwrap()), ["B"])
  assert_eq(same.edge_ids, [])
  assert_eq(same.authored_edge_count, 0)
  assert_true(tree.patristic_path("B", "B") is Err(@phylo.MissingLength(_)))
  assert_eq(tree.nodes(), before)
}

///|
test "authored route counts this subdivision and excludes stem" {
  let tree = @phylo.PhyloTree::from_newick("[&R]((((A:0)Q)U,B)X,(C,D)Y)R:99;").unwrap()
  let nodes = tree.nodes()
  let path = tree.authored_leaf_route("A", "C").unwrap()
  assert_eq(path.node_ids.map(i => nodes[i].label.unwrap()), [
    "A", "Q", "U", "X", "R", "Y", "C",
  ])
  assert_eq(path.edge_ids.map(i => nodes[i].label.unwrap()), [
    "A", "Q", "U", "X", "Y", "C",
  ])
  assert_eq(path.authored_edge_count, 6)
  assert_true(
    tree.authored_leaf_route("U", "C") is Err(@phylo.UnknownTaxon("U")),
  )
  assert_true(
    tree.authored_leaf_route("missing", "also missing")
    is Err(@phylo.UnknownTaxon("missing")),
  )
  assert_true(
    tree.authored_leaf_route("A", "missing")
    is Err(@phylo.UnknownTaxon("missing")),
  )
}

///|
test "authored route arrays are fresh and single-root self is empty" {
  let tree = @phylo.PhyloTree::from_newick("(A,B)R;").unwrap()
  let before = tree.nodes()
  let first = tree.authored_leaf_route("A", "B").unwrap()
  let second = tree.authored_leaf_route("A", "B").unwrap()
  first.node_ids.clear()
  first.edge_ids.push(-1)
  assert_eq(second.node_ids.map(i => before[i].label.unwrap()), ["A", "R", "B"])
  assert_eq(second.edge_ids.map(i => before[i].label.unwrap()), ["A", "B"])
  assert_eq(tree.nodes(), before)
  let leaf = @phylo.PhyloTree::from_newick("[&U]'only':99;").unwrap()
  let report = leaf.authored_leaf_route("only", "only").unwrap()
  assert_eq(report.node_ids, [leaf.root_id()])
  assert_eq(report.edge_ids, [])
  assert_eq(report.authored_edge_count, 0)
}
