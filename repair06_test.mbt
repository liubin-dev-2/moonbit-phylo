///|
test "repair06 incomplete retained paths propagate missing before overflow" {
  let t = read("(((A:1e308):1e308),B:1);")
  let r = t.prune(["A", "B"]).unwrap()
  assert_eq(r.tree.taxa(), ["A", "B"])
  let a = r.tree.nodes().filter(n => n.label == Some("A"))[0]
  assert_eq(a.length, None)
  assert_true(r.tree.patristic_matrix() is Err(@phylo.MissingLength(_)))
  check_mapping(t, r)
  // Complete retained paths must still reject actual numeric overflow.
  assert_true(
    read("(((A:1e308):1e308):0,B:1);").prune(["A", "B"])
    is Err(@phylo.NumericOverflow),
  )
}

///|
test "repair06 negative decimal lengths cannot become valid by underflow" {
  for text in ["-1e-400", "-0.01e-999", "-1000000e-999"] {
    assert_true(
      @phylo.PhyloTree::from_newick("(A:" + text + ",B:1);")
      is Err(@phylo.InvalidLength(_, _)),
      msg=text,
    )
  }
  // Preserve the existing accepted binary64 rounding policy and signed zero.
  for text in ["1e-400", "+1e-400", "-0.0", "-0e-400"] {
    let t = read("(A:" + text + ",B:1);")
    assert_eq(t.patristic_distance("A", "B"), Ok(1.0))
  }
  let negative = @phylo.NewickReader(rooted=true)
  assert_true(negative.feed("(A:-0.01e") is Ok(_))
  assert_true(negative.feed("-999,B:1);") is Err(@phylo.InvalidLength(_, _)))
  let zero = @phylo.NewickReader(rooted=true)
  assert_true(zero.feed("(A:-0e") is Ok(_))
  assert_true(zero.feed("-400,B:1);") is Ok(_))
  assert_eq(zero.finish().unwrap().patristic_distance("A", "B"), Ok(1.0))
}

///|
test "repair06 all contracted missing zero small huge segment combinations" {
  let segments : Array[Double?] = [None, Some(0.0), Some(1.0), Some(1.0e308)]
  for a in segments {
    for b in segments {
      for c in segments {
        let sa = match a {
          None => ""
          Some(x) => ":" + x.to_string()
        }
        let sb = match b {
          None => ""
          Some(x) => ":" + x.to_string()
        }
        let sc = match c {
          None => ""
          Some(x) => ":" + x.to_string()
        }
        let t = read("(((A" + sa + ")" + sb + ")" + sc + ",B:1);")
        let expected = match (a, b, c) {
          (Some(x), Some(y), Some(z)) => Some(x + y + z)
          _ => None
        }
        let result = t.prune(["A", "B"])
        if expected is Some(x) && x.is_inf() {
          assert_true(result is Err(@phylo.NumericOverflow))
        } else {
          let r = result.unwrap()
          assert_eq(r.tree.taxa(), ["A", "B"])
          assert_eq(
            r.tree.nodes().filter(n => n.label == Some("A"))[0].length,
            expected,
          )
          check_mapping(t, r)
          if expected is None {
            assert_true(
              r.tree.patristic_matrix() is Err(@phylo.MissingLength(_)),
            )
          }
        }
      }
    }
  }
}
