///|
test "ladderize owns arena child and comment storage independently" {
  let tree = PhyloTree::from_newick("[&R]((A,B)X[x],C)R[r];[tree]").unwrap()
  let original = tree.nodes()
  let text = tree.to_newick()
  let copy = tree.ladderize()
  let root = copy.root
  copy.arena[root].children.clear()
  copy.arena[root].comments.push("copy-root")
  copy.arena[1].comments.clear()
  copy.comments.clear()
  copy.arena[1].label = Some("copy-only")
  assert_eq(tree.nodes(), original)
  assert_eq(tree.to_newick(), text)
  assert_eq(tree.tree_comments(), ["tree"])
}
