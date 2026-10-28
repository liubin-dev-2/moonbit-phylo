///|
fn read(s : String) -> @phylo.PhyloTree {
  @phylo.PhyloTree::from_newick(s, rooted=true).unwrap()
}

///|
fn near(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() <= 0.0000000001 * (1.0 + b.abs()))
}

///|
fn check_assignment(
  t : @phylo.PhyloTree,
  r : @phylo.ParsimonyResult,
) -> Unit raise {
  let nodes = t.nodes()
  let mut changes = 0
  for n in nodes {
    if n.parent is Some(p) {
      if r.assignment[n.id] != r.assignment[p] {
        changes = changes + 1
      }
    }
  }
  assert_eq(changes, r.score)
}

///|
fn check_mapping(
  old : @phylo.PhyloTree,
  result : @phylo.TransformResult,
) -> Unit raise {
  let before = old.nodes()
  let after = result.tree.nodes()
  assert_eq(result.witness.old_to_new.length(), before.length())
  let inverse : Map[Int, Int] = Map([])
  for old_id, new_id in result.witness.old_to_new {
    if new_id is Some(id) {
      assert_true(!inverse.contains(id))
      inverse[id] = old_id
      assert_eq(after[id].label, before[old_id].label)
    }
  }
  for node in before {
    if node.children.is_empty() &&
      result.tree.taxa().contains(node.label.unwrap()) {
      let mapped = result.witness.old_to_new[node.id].unwrap()
      assert_eq(after[mapped].label, node.label)
      assert_true(after[mapped].children.is_empty())
    }
  }
  // Independent audit of each new edge as a walk in the original undirected
  // graph, augmented only with the declared diameter-edge subdivision.
  for node in after {
    if node.parent is Some(p) {
      let mut current = inverse.get(p).unwrap_or(before.length())
      let mut sum : Double? = Some(0.0)
      for point in result.witness.edge_paths[node.id] {
        let len : Double? = if current == before.length() ||
          point == before.length() {
          let other = if current == before.length() { point } else { current }
          let cut = result.witness.split_edge
          assert_eq(cut.length(), 2)
          assert_true(other == cut[0] || other == cut[1])
          if other == cut[0] {
            result.witness.offset
          } else {
            let original = if before[cut[0]].parent == Some(cut[1]) {
              before[cut[0]].length
            } else {
              before[cut[1]].length
            }
            Some(original.unwrap() - result.witness.offset.unwrap())
          }
        } else if before[point].parent == Some(current) {
          before[point].length
        } else {
          assert_eq(before[current].parent, Some(point))
          before[current].length
        }
        sum = match (sum, len) {
          (Some(a), Some(b)) => Some(a + b)
          _ => None
        }
        current = point
      }
      assert_eq(Some(current), inverse.get(node.id))
      match (sum, node.length) {
        (Some(a), Some(b)) => near(a, b)
        (None, None) => ()
        _ => fail("witness length completeness mismatch")
      }
    }
  }
}

///|
fn check_observations(
  t : @phylo.PhyloTree,
  r : @phylo.ParsimonyResult,
  traits : Map[String, Char],
) -> Unit raise {
  for n in t.nodes() {
    if n.children.is_empty() && traits[n.label.unwrap()] != '?' {
      assert_eq(r.assignment[n.id], Some(traits[n.label.unwrap()]))
    }
  }
}
