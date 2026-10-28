///|
test "path witness follows source edges in order including reverse zero and self" {
  let tree = @phylo.PhyloTree::from_newick(
    "[&U]((A:1,B:2)X:4,(C:0,D:3)Y:8,Z:0)R:99;",
  ).unwrap()
  let nodes = tree.nodes()
  let forward = tree.patristic_path("B", "C").unwrap()
  assert_eq(forward.from_taxon, "B")
  assert_eq(forward.to_taxon, "C")
  assert_eq(forward.node_ids.map(i => nodes[i].label.unwrap()), [
    "B", "X", "R", "Y", "C",
  ])
  assert_eq(forward.edge_ids.map(i => nodes[i].label.unwrap()), [
    "B", "X", "Y", "C",
  ])
  assert_eq(forward.distance, 14.0)
  assert_eq(tree.patristic_distance("B", "C").unwrap(), forward.distance)
  let reverse = tree.patristic_path("C", "B").unwrap()
  assert_eq(reverse.node_ids.map(i => nodes[i].label.unwrap()), [
    "C", "Y", "R", "X", "B",
  ])
  assert_eq(reverse.edge_ids.map(i => nodes[i].label.unwrap()), [
    "C", "Y", "X", "B",
  ])
  assert_eq(reverse.distance, 14.0)
  let same = tree.patristic_path("Z", "Z").unwrap()
  assert_eq(same.node_ids.map(i => nodes[i].label.unwrap()), ["Z"])
  assert_eq(same.edge_ids, [])
  assert_eq(same.distance.reinterpret_as_uint64(), 0UL)
}

///|
test "path witness retains one-round subnormal and requested-pair overflow rules" {
  let tree = @phylo.PhyloTree::from_newick(
    "[&U]((A:9007199254740992,T:1)X:1,B:1)R:7;",
  ).unwrap()
  assert_eq(tree.patristic_path("A", "B").unwrap().distance, 9007199254740994.0)
  assert_eq(tree.patristic_path("B", "A").unwrap().distance, 9007199254740994.0)
  let tiny = @phylo.PhyloTree::from_newick("[&U](A:5e-324,B:5e-324,C:0)R;").unwrap()
  assert_eq(
    tiny.patristic_path("A", "B").unwrap().distance.reinterpret_as_uint64(),
    2UL,
  )
  let huge = @phylo.PhyloTree::from_newick(
    "[&U]((A:1,B:1)X:1e308,(C:1,D:1)Y:1e308)R:1e308;",
  ).unwrap()
  assert_eq(huge.patristic_path("A", "B").unwrap().distance, 2.0)
  assert_true(huge.patristic_path("A", "C") is Err(@phylo.NumericOverflow))
}

///|
test "path witness keeps exact leaf identities and existing validation precedence" {
  let tree = @phylo.PhyloTree::from_newick(
    "('Café':1,'Café':2,'O''Brien_😀':0)R:99;",
  ).unwrap()
  let path = tree.patristic_path("Café", "Café").unwrap()
  assert_eq(path.distance, 3.0)
  assert_eq(path.node_ids.map(i => tree.nodes()[i].label.unwrap()), [
    "Café", "R", "Café",
  ])
  assert_true(
    tree.patristic_path("R", "Café") is Err(@phylo.UnknownTaxon("R")),
  )
  let missing = @phylo.PhyloTree::from_newick("[&R]((A:1,B:2)X:3,C)R;").unwrap()
  assert_true(missing.patristic_path("A", "B") is Err(@phylo.MissingLength(_)))
  assert_eq(
    missing.patristic_path("absent", "B").map(report => report.distance),
    missing.patristic_distance("absent", "B"),
  )
}
