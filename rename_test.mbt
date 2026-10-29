///|
test "taxon renames are simultaneous and preserve original graph metadata" {
  let tree = @phylo.PhyloTree::from_newick(
    "[&R](((A:0)U[old A; keep],B:1.5)X,(C,D:0)Y)Root[root A]:99;[tree A]",
  ).unwrap()
  let original = tree.nodes()
  let names = { "A": "B", "B": "A", "C": "C" }
  let result = tree.rename_taxa(names).unwrap()
  let after = result.tree.nodes()
  for node in original {
    let expected = if node.children.is_empty() {
      match node.label.unwrap() {
        "A" => Some("B")
        "B" => Some("A")
        other => Some(other)
      }
    } else {
      node.label
    }
    assert_eq(after[node.id].label, expected)
    assert_eq(after[node.id].parent, node.parent)
    assert_eq(after[node.id].children, node.children)
    assert_eq(after[node.id].length, node.length)
    assert_eq(after[node.id].comments, node.comments)
  }
  assert_eq(result.tree.tree_comments(), ["tree A"])
  assert_eq(result.tree.rooting(), tree.rooting())
  assert_eq(result.renames.map(row => (row.from_taxon, row.to_taxon)), [
    ("A", "B"),
    ("B", "A"),
    ("C", "C"),
  ])
  for row in result.renames {
    assert_eq(original[row.source_id].label, Some(row.from_taxon))
    assert_eq(after[row.target_id].label, Some(row.to_taxon))
  }
  names["A"] = "later caller edit"
  assert_eq(result.tree.nodes(), after)
  result.renames.clear()
  assert_eq(result.tree.nodes(), after)
  assert_eq(tree.nodes(), original)
}

///|
test "taxon rename validation is atomic and has declared priority" {
  let tree = @phylo.PhyloTree::from_newick("((A)U,B)Root;").unwrap()
  let before = tree.nodes()
  let a = before.filter(n => n.children.is_empty() && n.label == Some("A"))[0].id
  assert_true(
    tree.rename_taxa({ "A": "", "missing": "Z" })
    is Err(@phylo.UnknownTaxon("missing")),
  )
  assert_true(tree.rename_taxa({ "U": "Z" }) is Err(@phylo.UnknownTaxon("U")))
  assert_true(
    tree.rename_taxa({ "A": "B", "B": "" }) is Err(@phylo.AnonymousTaxon(_)),
  )
  assert_true(
    tree.rename_taxa({ "A": "" }) is Err(@phylo.AnonymousTaxon(id)) && id == a,
  )
  assert_true(tree.rename_taxa({ "A": "B" }) is Err(@phylo.DuplicateTaxon("B")))
  assert_true(
    tree.rename_taxa({ "A": "Z", "B": "Z" }) is Err(@phylo.DuplicateTaxon("Z")),
  )
  assert_eq(tree.nodes(), before)
  let unchanged = tree.rename_taxa(Map([])).unwrap()
  assert_eq(unchanged.tree.nodes(), before)
  assert_true(unchanged.renames.is_empty())
}

///|
test "taxon rename quoting and exact Unicode survive Newick handoff" {
  let tree = @phylo.PhyloTree::from_newick("[&U]((A:0,B)X,C)Root:99;").unwrap()
  let result = tree
    .rename_taxa({ "A": "X", "B": "O'Brien_😀;[x]", "C": " C " })
    .unwrap()
  let loaded = @phylo.PhyloTree::from_newick(result.tree.to_newick()).unwrap()
  assert_eq(loaded.taxa(), [" C ", "O'Brien_😀;[x]", "X"])
  assert_eq(loaded.rooting(), @phylo.Unrooted)
  let unicode = @phylo.PhyloTree::from_newick("(A,B)R;").unwrap()
  let renamed = unicode.rename_taxa({ "A": "Café", "B": "Café" }).unwrap()
  assert_eq(renamed.tree.taxa(), ["Café", "Café"])
  assert_eq(renamed.tree.rooting(), @phylo.Unknown)
  let leaf = @phylo.PhyloTree::from_newick("[&U]'A_B':99;").unwrap()
  assert_eq(leaf.rename_taxa({ "A_B": " " }).unwrap().tree.taxa(), [" "])
}
