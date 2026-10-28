///|
test "PD gain workflow preserves a small increment hidden by absolute rounding" {
  let tree = read("(A:10000000000000000,B:1)R;")
  let baseline = tree.faith_pd(["A"]).unwrap().total_length
  let combined = tree.faith_pd(["A", "B"]).unwrap().total_length
  assert_eq(baseline, 10000000000000000.0)
  assert_eq(combined, 10000000000000000.0)
  assert_eq(combined - baseline, 0.0)
  let report = tree.faith_pd_gain(["A"], ["B"]).unwrap()
  assert_eq(report.gain, 1.0)
  assert_eq(report.added_taxa, ["B"])
  assert_eq(report.edge_ids.length(), 1)
}

///|
test "PD gain workflow groups shared new ancestry once" {
  let tree = read("((A:1,B:2):3,(C:4,D:5):6)R;")
  let baseline = tree.faith_pd(["A"]).unwrap().total_length
  let c = tree.faith_pd(["A", "C"]).unwrap().total_length - baseline
  let d = tree.faith_pd(["A", "D"]).unwrap().total_length - baseline
  let cd = tree.faith_pd(["A", "C", "D"]).unwrap().total_length - baseline
  assert_eq(c, 10.0)
  assert_eq(d, 11.0)
  assert_eq(cd, 15.0)
  assert_eq(c + d, 21.0)
  let report = tree.faith_pd_gain(["A"], ["C", "D"]).unwrap()
  assert_eq(report.gain, 15.0)
  assert_eq(report.edge_ids.length(), 3)
}

///|
test "PD gain empty overlap decoded labels and zero branches" {
  let tree = read("('A_long':1,B:2,'龙,叶':3,'a b':4)R:999;")
  let before = tree.to_newick()
  let baseline = ["a b", "B"]
  let additions = ["龙,叶", "a b", "A_long"]
  let report = tree.faith_pd_gain(baseline, additions).unwrap()
  assert_eq(report.baseline_taxa, ["B", "a b"])
  assert_eq(report.added_taxa, ["A_long", "龙,叶"])
  assert_eq(report.gain, 4.0)
  assert_eq(report.root_id, tree.root_id())
  assert_eq(baseline, ["a b", "B"])
  assert_eq(additions, ["龙,叶", "a b", "A_long"])
  assert_eq(tree.to_newick(), before)
  let none = tree.faith_pd_gain(["B"], ["B"]).unwrap()
  assert_eq(none.added_taxa, [])
  assert_eq(none.edge_ids, [])
  assert_eq(none.gain, 0.0)
  let empty = tree.faith_pd_gain([], []).unwrap()
  assert_eq(empty.baseline_taxa, [])
  assert_eq(empty.added_taxa, [])
  assert_eq(empty.edge_ids, [])
  assert_eq(empty.gain, 0.0)
  let zero = read("(A:0,B:0,C:0):999;").faith_pd_gain(["A"], ["B"]).unwrap()
  assert_eq(zero.added_taxa, ["B"])
  assert_eq(zero.edge_ids.length(), 1)
  assert_eq(zero.gain, 0.0)
  let single = read("A:999;").faith_pd_gain([], ["A"]).unwrap()
  assert_eq(single.added_taxa, ["A"])
  assert_eq(single.edge_ids, [])
  assert_eq(single.gain, 0.0)
}

///|
test "PD gain rooting selections and complete length errors" {
  for prefix in ["", "[&U]"] {
    let tree = @phylo.PhyloTree::from_newick(prefix + "(A:1,B:2);").unwrap()
    assert_true(tree.faith_pd_gain([], []) is Err(@phylo.RootedTreeRequired))
  }
  let tree = read("(A:1,B:2);")
  assert_true(tree.faith_pd_gain(["Z"], []) is Err(@phylo.UnknownTaxon("Z")))
  assert_true(tree.faith_pd_gain([], ["Z"]) is Err(@phylo.UnknownTaxon("Z")))
  assert_true(
    tree.faith_pd_gain(["A", "A"], []) is Err(@phylo.DuplicateSelection("A")),
  )
  assert_true(
    tree.faith_pd_gain(["A"], ["A", "A"]) is Err(@phylo.DuplicateSelection("A")),
  )
  let missing = read("(A:1,B);")
  assert_true(missing.faith_pd_gain([], []) is Err(@phylo.MissingLength(_)))
}

///|
test "PD gain rounds new edges only and permits overflowing absolute baseline" {
  let huge = read("(A:1e308,B:1e308,C:1);")
  assert_true(huge.faith_pd(["A", "B"]) is Err(@phylo.NumericOverflow))
  assert_eq(huge.faith_pd_gain(["A", "B"], ["C"]).unwrap().gain, 1.0)
  assert_eq(huge.faith_pd_gain(["A", "B"], []).unwrap().gain, 0.0)
  assert_eq(huge.faith_pd_gain(["A"], ["B"]).unwrap().gain, 1.0e308)
  assert_true(
    huge.faith_pd_gain(["C"], ["A", "B"]) is Err(@phylo.NumericOverflow),
  )
  let finite = read(
    "((((A:1.7976931348623153e308):1.1975041857208318e292):1.1975041857208318e292):1.1975041857208318e292,B:0);",
  )
  assert_eq(
    finite.faith_pd_gain(["B"], ["A"]).unwrap().gain,
    1.7976931348623157e308,
  )
}

///|
// Audit newly covered source branches by independently supplied descendant-edge
// multisets, including repeated unary clades and zero-length branches.
fn check_pd_gain(
  tree : @phylo.PhyloTree,
  baseline : Array[String],
  additions : Array[String],
  expected_bits : UInt64,
  expected_edges : Array[(Array[String], Double)],
) -> Unit raise {
  let original = tree.to_newick()
  let old_input = baseline.copy()
  let new_input = additions.copy()
  let report = tree.faith_pd_gain(baseline, additions).unwrap()
  let sorted_old = baseline.copy()
  sorted_old.sort_by((a, b) => a.lexical_compare(b))
  let sorted_new = additions.filter(taxon => !baseline.contains(taxon))
  sorted_new.sort_by((a, b) => a.lexical_compare(b))
  assert_eq(report.baseline_taxa, sorted_old)
  assert_eq(report.added_taxa, sorted_new)
  assert_eq(report.root_id, tree.root_id())
  assert_eq(report.gain.reinterpret_as_uint64(), expected_bits)
  assert_eq(report.edge_ids.length(), expected_edges.length())
  let nodes = tree.nodes()
  let matched = Array::make(expected_edges.length(), false)
  let mut previous = -1
  for id in report.edge_ids {
    assert_true(id > previous)
    assert_true(id != tree.root_id())
    assert_true(nodes[id].parent is Some(_))
    previous = id
    let stack = [id]
    let descendants = []
    while !stack.is_empty() {
      let node = nodes[stack.pop().unwrap()]
      if node.children.is_empty() {
        descendants.push(node.label.unwrap())
      } else {
        stack.append(node.children)
      }
    }
    descendants.sort_by((a, b) => a.lexical_compare(b))
    let mut found = -1
    for i, (taxa, length) in expected_edges {
      if !matched[i] && taxa == descendants && nodes[id].length == Some(length) {
        found = i
        break
      }
    }
    assert_true(found >= 0)
    matched[found] = true
  }
  for flag in matched {
    assert_true(flag)
  }
  assert_eq(tree.to_newick(), original)
  assert_eq(baseline, old_input)
  assert_eq(additions, new_input)
}
