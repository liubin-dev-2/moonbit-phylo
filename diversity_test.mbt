///|
// Audit the reported source edges by descendant taxa, independently of root-path
// marking. Expected multisets come from hand sums or Biopython/Fraction fixtures.
fn check_pd(
  tree : @phylo.PhyloTree,
  present : Array[String],
  expected_bits : UInt64,
  expected_edges : Array[(Array[String], Double)],
) -> Unit raise {
  let original = tree.to_newick()
  let report = tree.faith_pd(present).unwrap()
  let sorted = present.copy()
  sorted.sort_by((a, b) => a.lexical_compare(b))
  assert_eq(report.selected_taxa, sorted)
  assert_eq(report.root_id, tree.root_id())
  assert_eq(report.total_length.reinterpret_as_uint64(), expected_bits)
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
}

///|
test "faith PD shared ancestry is counted once and root stem excluded" {
  let tree = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let ab = tree.faith_pd(["B", "A"]).unwrap()
  assert_eq(ab.total_length, 6.0) // A + B + their shared root branch
  assert_eq(ab.selected_taxa, ["A", "B"])
  assert_eq(tree.faith_pd(["A", "C"]).unwrap().total_length, 14.0)
  assert_eq(tree.faith_pd(["A"]).unwrap().total_length, 4.0)
  assert_eq(tree.faith_pd(tree.taxa()).unwrap().total_length, 21.0)
  let empty = tree.faith_pd([]).unwrap()
  assert_eq(empty.total_length, 0.0)
  assert_eq(empty.edge_ids, [])
  assert_eq(empty.selected_taxa, [])
  assert_eq(empty.root_id, tree.root_id())
  // prune retains the connecting subtree, not the ancestry required by Faith PD.
  assert_eq(
    tree.prune(["A", "B"]).unwrap().tree.patristic_distance("A", "B"),
    Ok(3.0),
  )
}

///|
test "faith PD explicit rootedness and selection length errors" {
  for prefix in ["", "[&U]"] {
    let tree = @phylo.PhyloTree::from_newick(prefix + "(A:1,B:2);").unwrap()
    assert_true(tree.faith_pd(["A"]) is Err(@phylo.RootedTreeRequired))
  }
  let tree = read("(A:1,B:2);")
  assert_true(tree.faith_pd(["Z"]) is Err(@phylo.UnknownTaxon("Z")))
  assert_true(tree.faith_pd(["A", "A"]) is Err(@phylo.DuplicateSelection("A")))
  let missing = read("(A:1,B);")
  assert_true(missing.faith_pd(["A"]) is Err(@phylo.MissingLength(_)))
  assert_true(missing.faith_pd([]) is Err(@phylo.MissingLength(_)))
}

///|
test "faith PD singleton zero polytomy and final numeric limits" {
  let one = read("A:999;").faith_pd(["A"]).unwrap()
  assert_eq(one.total_length, 0.0)
  assert_eq(one.edge_ids, [])
  let zero = read("(A:0,B:0,C:0):1e308;").faith_pd(["A", "C"]).unwrap()
  assert_eq(zero.total_length, 0.0)
  assert_eq(zero.edge_ids.length(), 2)
  let finite = read(
    "((((A:1.7976931348623153e308):1.1975041857208318e292):1.1975041857208318e292):1.1975041857208318e292,B:0);",
  )
  assert_eq(
    finite.faith_pd(["A"]).unwrap().total_length,
    1.7976931348623157e308,
  )
  let huge = read("(A:1e308,B:1e308);")
  assert_eq(huge.faith_pd(["A"]).unwrap().total_length, 1.0e308)
  assert_true(huge.faith_pd(["A", "B"]) is Err(@phylo.NumericOverflow))
}

///|
test "faith PD decoded taxa lexical order and input integrity" {
  let tree = read("('A_long':1,B:2,'龙,叶':3,'a b':4)R;")
  let before = tree.to_newick()
  let input = ["龙,叶", "B", "A_long", "a b"]
  let report = tree.faith_pd(input).unwrap()
  assert_eq(report.selected_taxa, ["A_long", "B", "a b", "龙,叶"])
  assert_eq(report.total_length, 10.0)
  assert_eq(input, ["龙,叶", "B", "A_long", "a b"])
  assert_eq(tree.to_newick(), before)
  assert_true(tree.faith_pd(["a_b"]) is Err(@phylo.UnknownTaxon("a_b")))
}
