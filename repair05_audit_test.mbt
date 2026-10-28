///|
// Exhaust every binary assignment on all nodes. This is not Fitch downpass.
fn exhaustive_binary_score(
  t : @phylo.PhyloTree,
  traits : Map[String, Char],
) -> Int {
  let nodes = t.nodes()
  let powers = []
  let mut assignments = 1
  for _ in nodes {
    powers.push(assignments)
    assignments = assignments * 2
  }
  let mut best = nodes.length()
  for mask = 0; mask < assignments; mask = mask + 1 {
    let mut valid = true
    let mut changes = 0
    for n in nodes {
      let state = mask / powers[n.id] % 2
      if n.children.is_empty() {
        let observation = traits[n.label.unwrap()]
        if (observation == '0' && state != 0) ||
          (observation == '1' && state != 1) {
          valid = false
        }
      }
      if n.parent is Some(p) && state != mask / powers[p] % 2 {
        changes = changes + 1
      }
    }
    if valid && changes < best {
      best = changes
    }
  }
  best
}

///|
test "repair05 all missing and mixed Fitch observations against exhaustive assignments" {
  for s in ["((A,B),(C,D));", "(A,(B,(C,D)));"] {
    let t = read(s)
    for code = 0; code < 81; code = code + 1 {
      let traits : Map[String, Char] = Map([])
      let mut digits = code
      for name in ["A", "B", "C", "D"] {
        traits[name] = (['0', '1', '?'] : Array[Char])[digits % 3]
        digits = digits / 3
      }
      let r = t.fitch_parsimony(traits).unwrap()
      assert_eq(r.score, exhaustive_binary_score(t, traits))
      check_assignment(t, r)
      check_observations(t, r, traits)
      assert_eq(r.changed_edges.length(), r.score)
      for (a, b) in r.changed_edges {
        assert_eq(t.nodes()[b].parent, Some(a))
        assert_true(r.assignment[a] != r.assignment[b])
      }
    }
  }
}

///|
test "repair05 complete RF reports against literal quartet clade and split sets" {
  let inputs = [
    "((A,B),(C,D));", "((A,C),(B,D));", "((A,D),(B,C));", "(A,(B,(C,D)));", "(A,B,C,D);",
    "((D,C),(B,A));", "(((A,B)),(C,D));",
  ]
  let clades = [
    [["A", "B"], ["C", "D"]],
    [["A", "C"], ["B", "D"]],
    [["A", "D"], ["B", "C"]],
    [["B", "C", "D"], ["C", "D"]],
    [],
    [["A", "B"], ["C", "D"]],
    [["A", "B"], ["C", "D"]],
  ]
  let splits = [
    [["C", "D"]],
    [["B", "D"]],
    [["B", "C"]],
    [["C", "D"]],
    [],
    [["C", "D"]],
    [["C", "D"]],
  ]
  for i = 0; i < inputs.length(); i = i + 1 {
    let a = read(inputs[i])
    let unknown = @phylo.PhyloTree::from_newick(inputs[i]).unwrap()
    assert_true(unknown.rf_distance_rooted(a) is Err(@phylo.RootedTreeRequired))
    for j = 0; j < inputs.length(); j = j + 1 {
      for rooted in [true, false] {
        let left = if rooted { clades[i] } else { splits[i] }
        let right = if rooted { clades[j] } else { splits[j] }
        let r = if rooted {
          a.rf_distance_rooted(read(inputs[j])).unwrap()
        } else {
          unknown.rf_distance_unrooted(read(inputs[j])).unwrap()
        }
        assert_eq(r.shared, left.filter(x => right.contains(x)))
        assert_eq(r.only_left, left.filter(x => !right.contains(x)))
        assert_eq(r.only_right, right.filter(x => !left.contains(x)))
        assert_eq(r.distance, r.only_left.length() + r.only_right.length())
        assert_eq(r.taxa, ["A", "B", "C", "D"])
      }
    }
  }
  assert_true(
    @phylo.PhyloTree::from_newick("(A_B,'A B');")
    is Err(@phylo.DuplicateTaxon("A B")),
  )
}

///|
test "repair05 zero subnormal ordinary and huge edge combinations preserve identities and witnesses" {
  let numbers = ["0", "4.9406564584124654e-324", "1", "1e308"]
  for a in numbers {
    for b in numbers {
      for c in numbers {
        let t = read("(A:" + a + ",B:" + b + ",C:" + c + ");")
        let nodes = t.nodes()
        let ids = nodes.filter(n => n.children.is_empty()).map(n => n.id)
        let mut overflow = false
        for x in ids {
          for y in ids {
            if x != y &&
              (nodes[x].length.unwrap() + nodes[y].length.unwrap()).is_inf() {
              overflow = true
            }
          }
        }
        if overflow {
          assert_true(t.midpoint_root() is Err(@phylo.NumericOverflow))
          continue
        }
        let r = t.midpoint_root().unwrap()
        assert_eq(r.tree.taxa(), ["A", "B", "C"])
        check_mapping(t, r)
        let before = t.patristic_matrix().unwrap()
        let after = r.tree.patristic_matrix().unwrap()
        for i = 0; i < 3; i = i + 1 {
          for j = 0; j < 3; j = j + 1 {
            if before.values[i][j] < 1.0 {
              assert_eq(after.values[i][j], before.values[i][j])
            } else {
              near(after.values[i][j], before.values[i][j])
            }
          }
        }
      }
    }
  }
}
