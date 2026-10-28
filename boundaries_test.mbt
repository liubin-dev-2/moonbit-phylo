///|
test "incremental quoting, Unicode, opaque nested comments, and round trip" {
  let s = "[&R][source]('龙''角':1.5[&&NHX:S=dragon],('a_b':2,C_D:3)[outer[inner]]:4)root:99;"
  let reader = @phylo.NewickReader()
  for c in s {
    assert_true(reader.feed(c.to_string()) is Ok(_))
  }
  let t = reader.finish().unwrap()
  assert_eq(t.taxa(), ["C D", "a_b", "龙'角"])
  assert_true(reader.finish() is Err(_))
  assert_true(reader.feed("A;") is Err(_))
  let round = @phylo.PhyloTree::from_newick(t.to_newick()).unwrap()
  assert_eq(t.nodes(), round.nodes())
  assert_eq(round.tree_comments(), ["source"])
  near(t.patristic_distance("龙'角", "a_b").unwrap(), 7.5)
}

///|
test "parser necessary error paths and rooting conflict" {
  for
    s in [
      "", "(A,B)", "(A,);", "();", "(A,B));", "A;B;", "A B;", "(A:bad,B:1);", "(A:-1,B:1);",
      "(A:1e999,B:1);", "(A:NaN,B:1);", "(A:1:2,B);", "(A:,B);", "('A,B);", "[open(A,B);",
      "(A]'x',B);", "A:'x';",
    ] {
    assert_true(@phylo.PhyloTree::from_newick(s) is Err(_), msg=s)
  }
  assert_true(
    @phylo.PhyloTree::from_newick("(A,A);") is Err(@phylo.DuplicateTaxon("A")),
  )
  assert_true(
    @phylo.PhyloTree::from_newick("('',B);") is Err(@phylo.AnonymousTaxon(_)),
  )
  assert_true(
    @phylo.PhyloTree::from_newick("[&R](A,B);", rooted=false)
    is Err(@phylo.RootingConflict),
  )
  let t = @phylo.PhyloTree::from_newick("(A,B);").unwrap()
  assert_eq(t.rooting(), @phylo.Unknown)
  assert_true(t.rf_distance_rooted(t) is Err(@phylo.RootedTreeRequired))
  assert_true(
    t.fitch_parsimony({ "A": '0', "B": '1' }) is Err(@phylo.RootedTreeRequired),
  )
  let r = @phylo.NewickReader()
  assert_true(r.feed("(A,);") is Err(_))
  assert_true(r.feed("A;") is Err(_))
  assert_true(r.finish() is Err(_))
}

///|
test "Fitch tree domain, mismatched traits, gap, all missing" {
  assert_true(
    read("(A,B,C);").fitch_parsimony({ "A": '0', "B": '1', "C": '0' })
    is Err(@phylo.PolytomyNotSupported(_, 3)),
  )
  assert_true(
    read("((A),B);").fitch_parsimony({ "A": '0', "B": '1' })
    is Err(@phylo.UnaryNotSupported(_)),
  )
  let t = read("(A,B);")
  assert_true(
    t.fitch_parsimony({ "A": '0', "C": '1' }) is Err(@phylo.TraitMismatch(_, _)),
  )
  assert_true(
    t.fitch_parsimony({ "A": '-', "B": '1' })
    is Err(@phylo.UnsupportedTrait("A")),
  )
  let unknown = t.fitch_parsimony({ "A": '?', "B": '?' }).unwrap()
  assert_eq(unknown.score, 0)
  assert_true(unknown.assignment.all(x => x is None))
  let nonbalanced = read("(A,(B,(C,D)));")
  assert_true(
    nonbalanced.fitch_parsimony({ "A": '0', "B": '1', "C": '0', "D": '1' })
    is Ok(_),
  )
  assert_true(
    t.rf_distance_unrooted(read("(A,C);")) is Err(@phylo.TaxaSetMismatch(_, _)),
  )
}

///|
test "length preconditions, numeric overflow, and stem exclusion" {
  let missing = read("(A,B:1);")
  assert_true(missing.patristic_matrix() is Err(@phylo.MissingLength(_)))
  assert_true(missing.midpoint_root() is Err(@phylo.MissingLength(_)))
  let t = read("(A:1,B:2):999;")
  near(t.patristic_distance("A", "B").unwrap(), 3.0)
  assert_true(t.patristic_distance("A", "X") is Err(@phylo.UnknownTaxon("X")))
  assert_true(
    read("(A:1e308,B:1e308);").patristic_matrix() is Err(@phylo.NumericOverflow),
  )
  assert_eq(read("A;").patristic_matrix().unwrap().values, [[0.0]])
  // Zero branches stay topological: no hidden length-based collapse.
  assert_eq(
    read("((A:0,B:0):0,(C:0,D:0):0);")
    .rf_distance_unrooted(read("(A,B,C,D);"))
    .unwrap().distance,
    1,
  )
}

///|
test "prune retain-set, singleton, missing propagation and isolated output" {
  let t = read("((A:1,B:2):3,C:4):88;")
  assert_true(t.prune([]) is Err(@phylo.EmptySelection))
  assert_true(t.prune(["A", "A"]) is Err(@phylo.DuplicateSelection("A")))
  assert_true(t.prune(["X"]) is Err(@phylo.UnknownTaxon("X")))
  let p = t.prune(["A", "C"]).unwrap()
  near(p.tree.patristic_distance("A", "C").unwrap(), 8.0)
  assert_eq(p.tree.taxa(), ["A", "C"])
  let one = t.prune(["B"]).unwrap()
  assert_eq(one.tree.taxa(), ["B"])
  assert_eq(one.tree.patristic_matrix().unwrap().values, [[0.0]])
  check_mapping(t, one)
  let unknown = read("((A:1,B:2),C:4);").prune(["A", "C"]).unwrap()
  assert_true(unknown.tree.patristic_matrix() is Err(@phylo.MissingLength(_)))
  let snapshot = t.nodes()
  snapshot[t.root_id()].children.clear()
  assert_eq(t.taxa(), ["A", "B", "C"])
}

///|
test "midpoint witnesses for zero diameter, internal vertex, edge split and unary root" {
  let zero = read("(A:0,B:0,C:0);").midpoint_root().unwrap()
  assert_eq(zero.witness.diameter, Some(0.0))
  assert_eq(zero.tree.taxa(), ["A", "B", "C"])
  for s in ["(A:1,B:1,C:1);", "(A:1,B:4);", "(((A:1,B:2):3):7);"] {
    let t = read(s)
    let r = t.midpoint_root().unwrap()
    check_mapping(t, r)
    let nodes = r.tree.nodes()
    let root_to_tip : Map[Int, Double] = Map([])
    root_to_tip[r.tree.root_id()] = 0.0
    // Public records are arena ordered, not necessarily traversal ordered.
    let stack = [r.tree.root_id()]
    while !stack.is_empty() {
      let id = stack.pop().unwrap()
      for c in nodes[id].children {
        root_to_tip[c] = root_to_tip[id] + nodes[c].length.unwrap()
        stack.push(c)
      }
    }
    for n in nodes {
      if n.children.is_empty() &&
        r.witness.diameter_endpoints.contains(n.label.unwrap()) {
        near(root_to_tip[n.id], r.witness.diameter.unwrap() / 2.0)
      }
    }
    let before = t.patristic_matrix().unwrap()
    let after = r.tree.patristic_matrix().unwrap()
    assert_eq(before.taxa, after.taxa)
    for i = 0; i < before.taxa.length(); i = i + 1 {
      for j = 0; j < before.taxa.length(); j = j + 1 {
        near(before.values[i][j], after.values[i][j])
      }
    }
  }
}

///|
test "10000 leaf comb parses writes and reads without recursive tree calls" {
  let s = StringBuilder()
  for _i = 0; _i < 9999; _i = _i + 1 {
    s.write_string("(")
  }
  s.write_string("T0")
  for i = 1; i < 10000; i = i + 1 {
    s.write_string(",T" + i.to_string() + ")")
  }
  s.write_string(";")
  let t = read(s.to_string())
  assert_eq(t.nodes().length(), 19999)
  let round = read(t.to_newick())
  assert_eq(round.taxa(), t.taxa())
}
