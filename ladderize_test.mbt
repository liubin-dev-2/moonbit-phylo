///|
test "ladderize stable sibling order preserves every original node attribute" {
  let tree = @phylo.PhyloTree::from_newick(
    "[&U](((A:0)U[u]:1,B:1e308)Pair[p],((C,D,E)Wide,F:1e308)Four,Z:0,(H,G)Tie:1.5)Root[r]:99;[tree note]",
  ).unwrap()
  let original = tree.nodes()
  let text = tree.to_newick()
  let root = tree.root_id()
  let ascending = tree.ladderize()
  let descending = tree.ladderize(reverse=true)
  let asc = ascending.nodes()
  let desc = descending.nodes()
  assert_eq(asc[root].children.map(id => asc[id].label.unwrap()), [
    "Z", "Pair", "Tie", "Four",
  ])
  assert_eq(desc[root].children.map(id => desc[id].label.unwrap()), [
    "Four", "Pair", "Tie", "Z",
  ])
  let four = original.filter(n => n.label == Some("Four"))[0].id
  assert_eq(asc[four].children.map(id => asc[id].label.unwrap()), ["F", "Wide"])
  assert_eq(desc[four].children.map(id => desc[id].label.unwrap()), [
    "Wide", "F",
  ])
  for label in ["Pair", "Tie", "Wide"] {
    let id = original.filter(n => n.label == Some(label))[0].id
    assert_eq(asc[id].children, original[id].children)
    assert_eq(desc[id].children, original[id].children)
  }
  for result in [ascending, descending] {
    let after = result.nodes()
    assert_eq(after.length(), original.length())
    for before in original {
      let found = after[before.id]
      assert_eq(found.parent, before.parent)
      assert_eq(found.label, before.label)
      assert_eq(found.length, before.length)
      assert_eq(found.comments, before.comments)
      let children = found.children.copy()
      let expected = before.children.copy()
      children.sort()
      expected.sort()
      assert_eq(children, expected)
    }
    assert_eq(result.root_id(), root)
    assert_eq(result.rooting(), @phylo.Unrooted)
    assert_eq(result.tree_comments(), ["tree note"])
  }
  assert_eq(tree.nodes(), original)
  assert_eq(tree.to_newick(), text)
}

///|
test "ladderize retains degenerate roots stable ties and repeat order" {
  for text in ["[&R]((A)U)Root;", "[&U]'Only':99;", "(Z,A,M)R;"] {
    let tree = @phylo.PhyloTree::from_newick(text).unwrap()
    let original = tree.nodes()
    for reverse in [false, true] {
      let result = tree.ladderize(reverse~)
      assert_eq(result.nodes(), original)
      assert_eq(result.rooting(), tree.rooting())
      assert_eq(result.to_newick(), tree.to_newick())
      assert_eq(result.ladderize(reverse~).nodes(), result.nodes())
    }
  }
  let tree = @phylo.PhyloTree::from_newick("((A,B)X,C,(E,D)Y)R;").unwrap()
  let desc = tree.ladderize(reverse=true)
  let asc = desc.ladderize()
  assert_eq(desc.to_newick(), "(('A','B')'X',('E','D')'Y','C')'R';")
  assert_eq(asc.to_newick(), "('C',('A','B')'X',('E','D')'Y')'R';")
  assert_eq(asc.ladderize().nodes(), asc.nodes())
  let source = StringBuilder()
  for _ in 0..<256 {
    source.write_string("(")
  }
  source.write_string("A")
  for _ in 0..<256 {
    source.write_string(")")
  }
  source.write_string(";")
  let spine = @phylo.PhyloTree::from_newick(source.to_string()).unwrap()
  assert_eq(spine.nodes().length(), 257)
  assert_eq(spine.ladderize().nodes(), spine.nodes())
}
