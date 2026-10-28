///|
test "repair07 finite exact path must not overflow from intermediate rounding" {
  // Fraction.from_float independently establishes exact sum <= largest finite
  // binary64 and final round-to-nearest = 1.7976931348623157e308.
  let t = read(
    "((((A:1.7976931348623153e308):1.1975041857208318e292):1.1975041857208318e292):1.1975041857208318e292,B:0);",
  )
  let expected = 1.7976931348623157e308
  assert_eq(t.patristic_distance("A", "B"), Ok(expected))
  assert_eq(t.patristic_distance("B", "A"), Ok(expected))
  assert_eq(t.patristic_matrix().unwrap().values, [
    [0.0, expected],
    [expected, 0.0],
  ])
  let pruned = t.prune(["A", "B"]).unwrap()
  assert_eq(pruned.tree.patristic_distance("A", "B"), Ok(expected))
  let rooted = t.midpoint_root().unwrap()
  assert_eq(rooted.tree.taxa(), ["A", "B"])
  assert_eq(rooted.witness.diameter, Some(expected))
  assert_eq(rooted.tree.patristic_distance("A", "B"), Ok(expected))
  for r in [pruned, rooted] {
    let old = t.nodes()
    let new = r.tree.nodes()
    for n in old {
      if n.children.is_empty() {
        let mapped = r.witness.old_to_new[n.id].unwrap()
        assert_eq(new[mapped].label, n.label)
        assert_true(new[mapped].children.is_empty())
      }
    }
  }
}

///|
test "repair07 path sums are symmetric and independent of unary grouping" {
  let t = read("(((A:1):1):10000000000000000,B:0);")
  let expected = 10000000000000002.0
  assert_eq(t.patristic_distance("A", "B"), Ok(expected))
  assert_eq(t.patristic_distance("B", "A"), Ok(expected))
  assert_eq(t.patristic_matrix().unwrap().values, [
    [0.0, expected],
    [expected, 0.0],
  ])
  assert_eq(
    t.prune(["A", "B"]).unwrap().tree.patristic_distance("A", "B"),
    Ok(expected),
  )
}
