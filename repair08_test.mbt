///|
test "repair08 midpoint reuses the exact vertex despite small path segments" {
  let t = read("(((((A:1):1):1):1):10000000000000000,B:10000000000000004)R;")
  let expected = 10000000000000004.0
  let r = t.midpoint_root().unwrap()
  if !r.witness.split_edge.is_empty() {
    println(r.tree.to_newick())
    println(r.witness.to_json().stringify())
  }
  assert_eq(r.witness.split_edge, [])
  assert_eq(r.witness.offset, None)
  assert_eq(r.witness.diameter, Some(20000000000000008.0))
  let old_root = t.root_id()
  let new_root = r.tree.root_id()
  assert_eq(r.witness.old_to_new[old_root], Some(new_root))
  assert_eq(r.tree.nodes()[new_root].label, Some("R"))
  let nodes = r.tree.nodes()
  for leaf in nodes.filter(n => n.children.is_empty()) {
    assert_eq(leaf.parent, Some(new_root))
    assert_eq(leaf.length, Some(expected))
  }
  assert_eq(r.tree.patristic_distance("A", "B"), Ok(20000000000000008.0))
  assert_eq(r.tree.taxa(), ["A", "B"])
}
