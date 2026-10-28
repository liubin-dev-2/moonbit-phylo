// Hand-tree and Fraction(actual binary64) expectations; no NJ oracle.

///|
test "range large_five" {
  let report = @nj.from_json(
    "{\"taxa\":[\"A\",\"B\",\"C\",\"D\",\"E\"],\"values\":[[0.0,2.8088955232223686e+307,1.1235582092889474e+308,1.6291594034689738e+308,1.6853373139334212e+308],[2.8088955232223686e+307,0.0,1.1797361197533948e+308,1.6853373139334212e+308,1.7415152243978685e+308],[1.1235582092889474e+308,1.1797361197533948e+308,0.0,1.0673802988245e+308,1.1235582092889474e+308],[1.6291594034689738e+308,1.6853373139334212e+308,1.0673802988245e+308,0.0,7.303128360378158e+307],[1.6853373139334212e+308,1.7415152243978685e+308,1.1235582092889474e+308,7.303128360378158e+307,0.0]]}",
  ).unwrap()
  assert_eq(report.tree.rooting(), @phylo.Unrooted)
  let expected : Array[Array[UInt64]] = [
    [
      0x0000000000000000UL, 0x7fc4000000000000UL, 0x7fe4000000000000UL, 0x7fed000000000000UL,
      0x7fee000000000000UL,
    ],
    [
      0x7fc4000000000000UL, 0x0000000000000000UL, 0x7fe5000000000000UL, 0x7fee000000000000UL,
      0x7fef000000000000UL,
    ],
    [
      0x7fe4000000000000UL, 0x7fe5000000000000UL, 0x0000000000000000UL, 0x7fe3000000000000UL,
      0x7fe4000000000000UL,
    ],
    [
      0x7fed000000000000UL, 0x7fee000000000000UL, 0x7fe3000000000000UL, 0x0000000000000000UL,
      0x7fda000000000000UL,
    ],
    [
      0x7fee000000000000UL, 0x7fef000000000000UL, 0x7fe4000000000000UL, 0x7fda000000000000UL,
      0x0000000000000000UL,
    ],
  ]
  for i = 0; i < expected.length(); i = i + 1 {
    for j = 0; j < expected.length(); j = j + 1 {
      assert_eq(
        report.fitted.values[i][j].reinterpret_as_uint64(),
        expected[i][j],
      )
    }
  }
  let pendant : Map[String, UInt64] = Map([
    ("A", 0x7fb0000000000000UL),
    ("B", 0x7fb8000000000000UL),
    ("C", 0x7fc4000000000000UL),
    ("D", 0x7fc8000000000000UL),
    ("E", 0x7fcc000000000000UL),
  ])
  for node in report.tree.nodes() {
    if node.children.is_empty() {
      assert_eq(
        node.length.unwrap().reinterpret_as_uint64(),
        pendant[node.label.unwrap()],
      )
    }
  }
  let reference = @phylo.PhyloTree::from_newick(
    "[&U]((A:1.1235582092889474e+307,B:1.6853373139334212e+307):7.3031283603781584e+307,C:2.8088955232223686e+307,(D:3.3706746278668423e+307,E:3.932453732511316e+307):4.4942328371557898e+307);",
  ).unwrap()
  assert_eq(report.tree.rf_distance_unrooted(reference).unwrap().distance, 0)
  assert_eq(report.max_abs_residual, 0.0)
  assert_true(report.tree.faith_pd(["A"]) is Err(@phylo.RootedTreeRequired))
}

///|
test "range maximum_star3" {
  let report = @nj.from_json(
    "{\"taxa\":[\"A\",\"B\",\"C\"],\"values\":[[0.0,1.7976931348623157e+308,1.7976931348623157e+308],[1.7976931348623157e+308,0.0,1.7976931348623157e+308],[1.7976931348623157e+308,1.7976931348623157e+308,0.0]]}",
  ).unwrap()
  assert_eq(report.tree.rooting(), @phylo.Unrooted)
  let expected : Array[Array[UInt64]] = [
    [0x0000000000000000UL, 0x7fefffffffffffffUL, 0x7fefffffffffffffUL],
    [0x7fefffffffffffffUL, 0x0000000000000000UL, 0x7fefffffffffffffUL],
    [0x7fefffffffffffffUL, 0x7fefffffffffffffUL, 0x0000000000000000UL],
  ]
  for i = 0; i < expected.length(); i = i + 1 {
    for j = 0; j < expected.length(); j = j + 1 {
      assert_eq(
        report.fitted.values[i][j].reinterpret_as_uint64(),
        expected[i][j],
      )
    }
  }
  let pendant : Map[String, UInt64] = Map([
    ("A", 0x7fdfffffffffffffUL),
    ("B", 0x7fdfffffffffffffUL),
    ("C", 0x7fdfffffffffffffUL),
  ])
  for node in report.tree.nodes() {
    if node.children.is_empty() {
      assert_eq(
        node.length.unwrap().reinterpret_as_uint64(),
        pendant[node.label.unwrap()],
      )
    }
  }
  let reference = @phylo.PhyloTree::from_newick(
    "[&U](A:8.9884656743115785e+307,B:8.9884656743115785e+307,C:8.9884656743115785e+307);",
  ).unwrap()
  assert_eq(report.tree.rf_distance_unrooted(reference).unwrap().distance, 0)
  assert_eq(report.max_abs_residual, 0.0)
  assert_true(report.tree.faith_pd(["A"]) is Err(@phylo.RootedTreeRequired))
}

///|
test "range mixed_normal" {
  let report = @nj.from_json(
    "{\"taxa\":[\"A\",\"B\",\"C\",\"D\"],\"values\":[[0.0,1.8665272370064378e-301,8.98846567431158e+307,8.98846567431158e+307],[1.8665272370064378e-301,0.0,8.98846567431158e+307,8.98846567431158e+307],[8.98846567431158e+307,8.98846567431158e+307,0.0,4.49423283715579e+307],[8.98846567431158e+307,8.98846567431158e+307,4.49423283715579e+307,0.0]]}",
  ).unwrap()
  assert_eq(report.tree.rooting(), @phylo.Unrooted)
  let expected : Array[Array[UInt64]] = [
    [
      0x0000000000000000UL, 0x0180000000000000UL, 0x7fe0000000000000UL, 0x7fe0000000000000UL,
    ],
    [
      0x0180000000000000UL, 0x0000000000000000UL, 0x7fe0000000000000UL, 0x7fe0000000000000UL,
    ],
    [
      0x7fe0000000000000UL, 0x7fe0000000000000UL, 0x0000000000000000UL, 0x7fd0000000000000UL,
    ],
    [
      0x7fe0000000000000UL, 0x7fe0000000000000UL, 0x7fd0000000000000UL, 0x0000000000000000UL,
    ],
  ]
  for i = 0; i < expected.length(); i = i + 1 {
    for j = 0; j < expected.length(); j = j + 1 {
      assert_eq(
        report.fitted.values[i][j].reinterpret_as_uint64(),
        expected[i][j],
      )
    }
  }
  let pendant : Map[String, UInt64] = Map([
    ("A", 0x0170000000000000UL),
    ("B", 0x0170000000000000UL),
    ("C", 0x7fc0000000000000UL),
    ("D", 0x7fc0000000000000UL),
  ])
  for node in report.tree.nodes() {
    if node.children.is_empty() {
      assert_eq(
        node.length.unwrap().reinterpret_as_uint64(),
        pendant[node.label.unwrap()],
      )
    }
  }
  let reference = @phylo.PhyloTree::from_newick(
    "[&U]((A:9.3326361850321888e-302,B:9.3326361850321888e-302):6.7413492557336847e+307,C:2.2471164185778949e+307,D:2.2471164185778949e+307);",
  ).unwrap()
  assert_eq(report.tree.rf_distance_unrooted(reference).unwrap().distance, 0)
  assert_eq(report.max_abs_residual, 0.0)
  assert_true(report.tree.faith_pd(["A"]) is Err(@phylo.RootedTreeRequired))
}

///|
test "range mixed_subnormal" {
  assert_true(
    @nj.from_json(
      "{\"taxa\":[\"A\",\"B\",\"C\",\"D\"],\"values\":[[0.0,1e-323,8.98846567431158e+307,8.98846567431158e+307],[1e-323,0.0,8.98846567431158e+307,8.98846567431158e+307],[8.98846567431158e+307,8.98846567431158e+307,0.0,4.49423283715579e+307],[8.98846567431158e+307,8.98846567431158e+307,4.49423283715579e+307,0.0]]}",
    )
    is Err(@nj.NumericOverflow("scale_input_range")),
  )
}

///|
test "range large_negative" {
  match
    @nj.from_json(
      "{\"taxa\":[\"A\",\"B\",\"C\",\"D\"],\"values\":[[0.0,2.247116418577895e+307,2.247116418577895e+307,2.247116418577895e+307],[2.247116418577895e+307,0.0,6.741349255733685e+307,6.741349255733685e+307],[2.247116418577895e+307,6.741349255733685e+307,0.0,4.49423283715579e+307],[2.247116418577895e+307,6.741349255733685e+307,4.49423283715579e+307,0.0]]}",
    ) {
    Err(@nj.NegativeLimb(taxa, length)) => {
      assert_eq(taxa, ["A"])
      assert_eq(length.reinterpret_as_uint64(), 0xffb0000000000000UL)
    }
    _ => abort("Expected negative limb in original units")
  }
}

///|
test "range fitted_path_overflow" {
  assert_true(
    @nj.from_json(
      "{\"taxa\":[\"A\",\"B\",\"C\",\"D\"],\"values\":[[0.0,8.707576121989343e+307,1.3061364182984014e+308,1.7415152243978685e+308],[8.707576121989343e+307,0.0,1.7415152243978685e+308,1.7415152243978685e+308],[1.3061364182984014e+308,1.7415152243978685e+308,0.0,8.707576121989343e+307],[1.7415152243978685e+308,1.7415152243978685e+308,8.707576121989343e+307,0.0]]}",
    )
    is Err(@nj.NumericOverflow("fitted_paths")),
  )
}

///|
test "range mixed_intermediate" {
  assert_true(
    @nj.from_json(
      "{\"taxa\":[\"A\",\"B\",\"C\",\"D\"],\"values\":[[0.0,5.696189077778437e-306,8.98846567431158e+307,8.98846567431158e+307],[5.696189077778437e-306,0.0,8.98846567431158e+307,8.98846567431158e+307],[8.98846567431158e+307,8.98846567431158e+307,0.0,4.49423283715579e+307],[8.98846567431158e+307,8.98846567431158e+307,4.49423283715579e+307,0.0]]}",
    )
    is Err(@nj.NumericOverflow("limb_half_scaled_range")),
  )
}
