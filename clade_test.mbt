///|
test "rooted clade gives original MRCA and complete intruder evidence" {
  let tree = @phylo.PhyloTree::from_newick(
    "[&R]((((A)U,B)AB,C)ABC,(D,E,F)DEF)Study[study-note]:777;",
  ).unwrap()
  let original = tree.nodes()
  for
    (selection, role, clade, extra) in [
      (["B", "A"], "AB", ["A", "B"], []),
      (["A", "C"], "ABC", ["A", "B", "C"], ["B"]),
      (["D", "F"], "DEF", ["D", "E", "F"], ["E"]),
      (
        ["A", "D"],
        "Study",
        ["A", "B", "C", "D", "E", "F"],
        ["B", "C", "E", "F"],
      ),
      (["A"], "A", ["A"], []),
    ] {
    let result = tree.rooted_clade(selection).unwrap()
    assert_eq(original[result.mrca_id].label, Some(role))
    assert_eq(result.clade_taxa, clade)
    assert_eq(result.extra_taxa, extra)
    assert_eq(result.is_monophyletic, extra.is_empty())
  }
  assert_eq(tree.nodes(), original)
  assert_true(tree.rooted_clade([]) is Err(@phylo.EmptySelection))
  assert_true(tree.rooted_clade(["AB"]) is Err(@phylo.UnknownTaxon("AB")))
  assert_true(
    tree.rooted_clade(["missing", "A", "A"])
    is Err(@phylo.UnknownTaxon("missing")),
  )
  assert_true(
    tree.rooted_clade(["A", "A", "missing"])
    is Err(@phylo.DuplicateSelection("A")),
  )
}

///|
test "rooted clade requires a root and ignores lengths without changing it" {
  for marker in ["", "[&U]"] {
    let tree = @phylo.PhyloTree::from_newick("\{marker}(A,B)R;").unwrap()
    assert_true(tree.rooted_clade([]) is Err(@phylo.RootedTreeRequired))
    assert_true(
      tree.rooted_clade(["missing"]) is Err(@phylo.RootedTreeRequired),
    )
  }
  let left = @phylo.PhyloTree::from_newick("[&R]((A,B)AB,(C,D)CD)R;").unwrap()
  let right = @phylo.PhyloTree::from_newick("[&R](A,(B,(C,D)CD)BCD)R;").unwrap()
  assert_true(left.rooted_clade(["A", "B"]).unwrap().is_monophyletic)
  assert_eq(right.rooted_clade(["A", "B"]).unwrap().extra_taxa, ["C", "D"])
  let huge = @phylo.PhyloTree::from_newick(
    "[&R]((A:1e308,B:1e308)AB:1e308,C:0)R:99;",
  ).unwrap()
  assert_true(huge.rooted_clade(["A", "B"]).unwrap().is_monophyletic)
  let unary = @phylo.PhyloTree::from_newick("[&R](((A)Inner)Stem)Outer:99;").unwrap()
  let report = unary.rooted_clade(["A"]).unwrap()
  assert_eq(unary.nodes()[report.mrca_id].label, Some("A"))
  let only = @phylo.PhyloTree::from_newick("[&R]Solo:99;").unwrap()
  assert_eq(only.rooted_clade(["Solo"]).unwrap().mrca_id, only.root_id())
}

///|
test "rooted clade has exact names and independent input and report arrays" {
  let tree = @phylo.PhyloTree::from_newick(
    "[&R](('Café','Café')Accents,('O''Brien_😀','😀','')Other)Root;",
  ).unwrap()
  let before = tree.nodes()
  let selection = ["", "😀"]
  let first = tree.rooted_clade(selection).unwrap()
  let second = tree.rooted_clade(selection).unwrap()
  assert_eq(selection, ["", "😀"])
  assert_eq(first.selected_taxa, ["😀", ""])
  assert_eq(first.clade_taxa, ["O'Brien_😀", "😀", ""])
  assert_eq(first.extra_taxa, ["O'Brien_😀"])
  first.selected_taxa.clear()
  first.clade_taxa.clear()
  first.extra_taxa.push("unowned")
  assert_eq(second.selected_taxa, ["😀", ""])
  assert_eq(second.clade_taxa, ["O'Brien_😀", "😀", ""])
  assert_eq(second.extra_taxa, ["O'Brien_😀"])
  selection.clear()
  assert_eq(second.selected_taxa, ["😀", ""])
  assert_eq(tree.nodes(), before)
  assert_eq(tree.rooted_clade(["Café", "Café"]).unwrap().extra_taxa, [])
}
