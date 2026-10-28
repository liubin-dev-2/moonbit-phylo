///|
test "repair05 finite selected paths do not inherit unrelated overflow" {
  let t = read("(A:1e308,B:1e308,C:1);")
  assert_eq(t.patristic_distance("A", "C"), Ok(1.0e308))
  assert_eq(t.patristic_distance("C", "A"), Ok(1.0e308))
  assert_eq(t.patristic_distance("A", "A"), Ok(0.0))
  assert_true(t.patristic_distance("A", "B") is Err(@phylo.NumericOverflow))
  assert_true(t.patristic_matrix() is Err(@phylo.NumericOverflow))
  // The long unary ancestry is outside every leaf-to-leaf path.
  let stem = read("(((A:1,B:2):1e308):1e308);")
  assert_eq(stem.patristic_matrix().unwrap().values, [[0.0, 3.0], [3.0, 0.0]])
  let r = stem.midpoint_root().unwrap()
  assert_eq(r.tree.taxa(), stem.taxa())
  near(r.tree.patristic_distance("A", "B").unwrap(), 3.0)
  check_mapping(stem, r)
}

///|
test "repair05 prune never sums a discarded root stem" {
  let t = read("((((A:1,B:2):1e308):1e308):1e308,C:1);")
  let one = t.prune(["A"]).unwrap()
  assert_eq(one.tree.taxa(), ["A"])
  assert_eq(one.tree.patristic_matrix().unwrap().values, [[0.0]])
  check_mapping(t, one)
  let pair = t.prune(["A", "B"]).unwrap()
  assert_eq(pair.tree.patristic_matrix().unwrap().values, [
    [0.0, 3.0],
    [3.0, 0.0],
  ])
  assert_eq(pair.tree.nodes()[pair.tree.root_id()].length, None)
  check_mapping(t, pair)
  // An overflowing path which survives must still fail.
  assert_true(
    read("((A:1e308):1e308,B:1);").prune(["A", "B"])
    is Err(@phylo.NumericOverflow),
  )
}

///|
test "repair05 smallest positive diameter preserves every taxon" {
  for
    s in [
      "(A:0,B:4.9406564584124654e-324);", "(A:4.9406564584124654e-324,B:0);",
    ] {
    let t = read(s)
    let d = t.patristic_distance("A", "B").unwrap()
    assert_true(d > 0.0)
    assert_eq(d / 2.0, 0.0)
    let r = t.midpoint_root().unwrap()
    assert_eq(r.tree.taxa(), ["A", "B"])
    assert_eq(r.witness.retained_taxa, ["A", "B"])
    assert_eq(r.tree.patristic_distance("A", "B"), Ok(d))
    assert_eq(r.witness.diameter, Some(d))
    assert_eq(r.tree.rf_distance_unrooted(t).unwrap().distance, 0)
    check_mapping(t, r)
  }
}

///|
test "repair05 opaque rooting-like comments cannot change Unknown on round trip" {
  for flag in ["&R", "&U"] {
    let t = @phylo.PhyloTree::from_newick("([" + flag + "]A:1,B:2);").unwrap()
    assert_eq(t.rooting(), @phylo.Unknown)
    let round = @phylo.PhyloTree::from_newick(t.to_newick()).unwrap()
    assert_eq(round.rooting(), @phylo.Unknown)
    assert_eq(round.tree_comments(), t.tree_comments())
    assert_true(
      round.rf_distance_rooted(round) is Err(@phylo.RootedTreeRequired),
    )
    // Also preserve tree-level opacity when pruning leaves only one node.
    let single = t.prune(["A"]).unwrap().tree
    let one = @phylo.PhyloTree::from_newick(single.to_newick()).unwrap()
    assert_eq(one.rooting(), @phylo.Unknown)
    assert_eq(one.tree_comments(), single.tree_comments())
  }
}
