///|
test "repair08 exact symmetric arm sums preserve the authored midpoint vertex" {
  let cases : Array[(String, UInt64, UInt64)] = [
    (
      "(((((A:1.0):1.0):1.0):1.0):1e+16,((((B:1e+16):1.0):1.0):1.0):1.0)R;", 0x4341c37937e08002UL,
      0x4351c37937e08002UL,
    ),
    (
      "((A:1.0):1e+16,(B:1e+16):1.0)R;", 0x4341c37937e08000UL, 0x4351c37937e08000UL,
    ),
    (
      "(((((A:1e+16):1.0):1.0):1.0):1.0,((((B:1.0):1.0):1.0):1.0):1e+16)R;", 0x4341c37937e08002UL,
      0x4351c37937e08002UL,
    ),
    (
      "(((A:1.0):1.1102230246251565e-16):5e-324,((B:5e-324):1.1102230246251565e-16):1.0)R;",
      0x3ff0000000000001UL, 0x4000000000000001UL,
    ),
    ("(A:5e-324,B:5e-324)R;", 0x0000000000000001UL, 0x0000000000000002UL),
    (
      "(((A:5e-324):5e-324):5e-324,((B:5e-324):5e-324):5e-324)R;", 0x0000000000000003UL,
      0x0000000000000006UL,
    ),
    (
      "((A:2.225073858507201e-308):5e-324,(B:5e-324):2.225073858507201e-308)R;",
      0x0010000000000000UL, 0x0020000000000000UL,
    ),
    (
      "((A:0.5):5.551115123125783e-17,(B:5.551115123125783e-17):0.5)R;", 0x3fe0000000000000UL,
      0x3ff0000000000000UL,
    ),
    (
      "((A:3.273390607896142e+150):3.6341936214780345e+134,(B:3.6341936214780345e+134):3.273390607896142e+150)R;",
      0x5f30000000000000UL, 0x5f40000000000000UL,
    ),
    (
      "((A:3.054936363499605e-151):3.391660689521908e-167,(B:3.391660689521908e-167):3.054936363499605e-151)R;",
      0x20b0000000000000UL, 0x20c0000000000000UL,
    ),
    (
      "((A:4.49423283715579e+307):4.9896007738368e+291,(B:4.9896007738368e+291):4.49423283715579e+307)R;",
      0x7fd0000000000000UL, 0x7fe0000000000000UL,
    ),
  ]
  for (text, arm_bits, diameter_bits) in cases {
    let t = read(text)
    let r = t.midpoint_root().unwrap()
    assert_eq(r.witness.split_edge, [])
    assert_eq(r.witness.offset, None)
    assert_eq(r.witness.old_to_new[t.root_id()], Some(r.tree.root_id()))
    assert_eq(r.tree.nodes()[r.tree.root_id()].label, Some("R"))
    assert_eq(r.witness.diameter, Some(diameter_bits.reinterpret_as_double()))
    assert_eq(r.tree.taxa(), ["A", "B"])
    for leaf in r.tree.nodes().filter(n => n.children.is_empty()) {
      assert_eq(leaf.parent, Some(r.tree.root_id()))
      assert_eq(leaf.length, Some(arm_bits.reinterpret_as_double()))
    }
    assert_eq(
      r.tree.patristic_distance("A", "B"),
      Ok(diameter_bits.reinterpret_as_double()),
    )
  }
}
