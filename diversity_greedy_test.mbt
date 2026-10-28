///|
test "PD greedy workflow initial ranking misses changing shared ancestry" {
  let tree = read("((A:1,B:8):3,(C:4,D:5):6)R;")
  assert_eq(tree.faith_pd_gain(["A"], ["B"]).unwrap().gain, 8.0)
  assert_eq(tree.faith_pd_gain(["A"], ["C"]).unwrap().gain, 10.0)
  assert_eq(tree.faith_pd_gain(["A"], ["D"]).unwrap().gain, 11.0)
  assert_eq(tree.faith_pd_gain(["A"], ["D", "C"]).unwrap().gain, 15.0)
  assert_eq(tree.faith_pd_gain(["A", "D"], ["B"]).unwrap().gain, 8.0)
  assert_eq(tree.faith_pd_gain(["A", "D"], ["C"]).unwrap().gain, 4.0)
  assert_eq(tree.faith_pd_gain(["A"], ["D", "B"]).unwrap().gain, 19.0)
  let plan = tree.faith_pd_greedy(["A"], ["B", "C", "D"], 2U).unwrap()
  assert_eq(plan.added_taxa, ["D", "B"])
  assert_eq(plan.selected_taxa, ["A", "B", "D"])
  assert_eq(plan.gain, 19.0)
  assert_eq(plan.steps.map(step => step.gain), [11.0, 8.0])
}

///|
test "PD greedy workflow rounded gains conceal a strict exact ordering" {
  let tree = read("(A:10000000000000000,(B:10000000000000000):1)R;")
  let a = tree.faith_pd_gain([], ["A"]).unwrap()
  let b = tree.faith_pd_gain([], ["B"]).unwrap()
  assert_eq(a.gain, 10000000000000000.0)
  assert_eq(b.gain, a.gain)
  assert_eq(a.edge_ids.length(), 1)
  assert_eq(b.edge_ids.length(), 2)
  let plan = tree.faith_pd_greedy([], ["A", "B"], 1U).unwrap()
  assert_eq(plan.added_taxa, ["B"])
  assert_eq(plan.gain, 10000000000000000.0)
  assert_eq(plan.steps[0].edge_ids.length(), 2)
}

///|
test "PD greedy zero limits overlap lexical ties and exhausted candidates" {
  let tree = read("('A_long':0,B:0,'龙':0)R:999;")
  let baseline : Array[String] = []
  let candidates = ["龙", "B", "A_long"]
  let before = tree.to_newick()
  let plan = tree.faith_pd_greedy(baseline, candidates, 2U).unwrap()
  assert_eq(plan.added_taxa, ["A_long", "B"])
  assert_eq(plan.gain, 0.0)
  assert_eq(plan.edge_ids.length(), 2)
  assert_eq(plan.steps.map(step => step.gain), [0.0, 0.0])
  assert_eq(
    tree.faith_pd_greedy([], candidates, 0xffffffffU).unwrap().steps.length(),
    3,
  )
  let overlap = tree.faith_pd_greedy(["B"], ["B", "龙"], 3U).unwrap()
  assert_eq(overlap.candidate_taxa, ["龙"])
  assert_eq(overlap.added_taxa, ["龙"])
  assert_eq(overlap.selected_taxa, ["B", "龙"])
  let zero = tree.faith_pd_greedy(["B"], candidates, 0U).unwrap()
  assert_eq(zero.selected_taxa, ["B"])
  assert_eq(zero.steps.length(), 0)
  assert_eq(zero.edge_ids, [])
  assert_eq(zero.gain, 0.0)
  assert_eq(tree.faith_pd_greedy([], [], 0xffffffffU).unwrap().added_taxa, [])
  let one = read("A:999;").faith_pd_greedy([], ["A"], 2U).unwrap()
  assert_eq(one.added_taxa, ["A"])
  assert_eq(one.steps[0].edge_ids, [])
  assert_eq(one.gain, 0.0)
  assert_eq(baseline, [])
  assert_eq(candidates, ["龙", "B", "A_long"])
  assert_eq(tree.to_newick(), before)
}

///|
test "PD greedy validates rootedness all candidates and missing lengths" {
  for prefix in ["", "[&U]"] {
    let tree = @phylo.PhyloTree::from_newick(prefix + "(A:1,B:2);").unwrap()
    assert_true(
      tree.faith_pd_greedy([], [], 0U) is Err(@phylo.RootedTreeRequired),
    )
  }
  let tree = read("(A:1,B:2);")
  assert_true(
    tree.faith_pd_greedy(["Z"], [], 0U) is Err(@phylo.UnknownTaxon("Z")),
  )
  assert_true(
    tree.faith_pd_greedy([], ["Z"], 0U) is Err(@phylo.UnknownTaxon("Z")),
  )
  assert_true(
    tree.faith_pd_greedy(["A", "A"], [], 0U)
    is Err(@phylo.DuplicateSelection("A")),
  )
  assert_true(
    tree.faith_pd_greedy(["A"], ["A", "A"], 0U)
    is Err(@phylo.DuplicateSelection("A")),
  )
  assert_true(
    read("(A:1,B);").faith_pd_greedy([], [], 0U) is Err(@phylo.MissingLength(_)),
  )
}

///|
test "PD greedy only returned gains must be finite" {
  let huge = read("(A:1e308,B:1e308,C:1);")
  assert_eq(huge.faith_pd_greedy(["A", "B"], ["C"], 1U).unwrap().gain, 1.0)
  assert_eq(huge.faith_pd_greedy(["A"], ["B"], 1U).unwrap().gain, 1.0e308)
  assert_true(
    huge.faith_pd_greedy([], ["A", "B"], 2U) is Err(@phylo.NumericOverflow),
  )
  let overflow_path = read("((A:1e308):1e308,B:1);")
  assert_eq(overflow_path.faith_pd_greedy([], ["A"], 0U).unwrap().gain, 0.0)
  assert_true(
    overflow_path.faith_pd_greedy([], ["A"], 1U) is Err(@phylo.NumericOverflow),
  )
}

///|
test "PD greedy aggregate rounds exact union once" {
  let tree = read("(A:10000000000000000,B:1,C:1)R;")
  let plan = tree.faith_pd_greedy([], ["A", "B", "C"], 3U).unwrap()
  assert_eq(plan.added_taxa, ["A", "B", "C"])
  assert_eq(plan.steps.map(step => step.gain), [10000000000000000.0, 1.0, 1.0])
  assert_eq(plan.gain, 10000000000000002.0)
}

///|
fn check_greedy_edges(
  nodes : Array[@phylo.NodeRecord],
  ids : Array[Int],
  expected : Array[(Array[String], Double)],
) -> Unit raise {
  assert_eq(ids.length(), expected.length())
  let matched = Array::make(expected.length(), false)
  let mut previous = -1
  for id in ids {
    assert_true(id > previous)
    assert_true(nodes[id].parent is Some(_))
    previous = id
    let stack = [id]
    let tips = []
    while !stack.is_empty() {
      let node = nodes[stack.pop().unwrap()]
      if node.children.is_empty() {
        tips.push(node.label.unwrap())
      } else {
        stack.append(node.children)
      }
    }
    tips.sort_by((a, b) => a.lexical_compare(b))
    let mut found = -1
    for i, (taxa, length) in expected {
      if !matched[i] && taxa == tips && nodes[id].length == Some(length) {
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
}

///|
fn check_pd_greedy(
  tree : @phylo.PhyloTree,
  baseline : Array[String],
  candidates : Array[String],
  limit : UInt,
  order : Array[String],
  expected_gain : UInt64,
  expected_steps : Array[(String, UInt64, Array[(Array[String], Double)])],
) -> Unit raise {
  let original = tree.to_newick()
  let old_input = baseline.copy()
  let pool_input = candidates.copy()
  let plan = tree.faith_pd_greedy(baseline, candidates, limit).unwrap()
  let sorted_old = baseline.copy()
  sorted_old.sort_by((a, b) => a.lexical_compare(b))
  let pool = candidates.filter(x => !baseline.contains(x))
  pool.sort_by((a, b) => a.lexical_compare(b))
  let selected = baseline.copy()
  selected.append(order)
  selected.sort_by((a, b) => a.lexical_compare(b))
  assert_eq(plan.baseline_taxa, sorted_old)
  assert_eq(plan.candidate_taxa, pool)
  assert_eq(plan.limit, limit)
  assert_eq(plan.added_taxa, order)
  assert_eq(plan.selected_taxa, selected)
  assert_eq(plan.root_id, tree.root_id())
  assert_eq(plan.gain.reinterpret_as_uint64(), expected_gain)
  assert_eq(plan.steps.length(), expected_steps.length())
  let nodes = tree.nodes()
  let used = Array::make(nodes.length(), false)
  let union_ids = []
  for i, step in plan.steps {
    let (taxon, expected, edges) = expected_steps[i]
    assert_eq(step.taxon, taxon)
    assert_eq(step.gain.reinterpret_as_uint64(), expected)
    check_greedy_edges(nodes, step.edge_ids, edges)
    for id in step.edge_ids {
      assert_true(!used[id])
      used[id] = true
      union_ids.push(id)
    }
  }
  union_ids.sort_by((a, b) => a.compare(b))
  assert_eq(plan.edge_ids, union_ids)
  assert_eq(tree.to_newick(), original)
  assert_eq(baseline, old_input)
  assert_eq(candidates, pool_input)
}
