///|
fn four(values : Array[Array[Double]]) -> @phylo.DistanceMatrix {
  { taxa: ["A", "B", "C", "D"], values, }
}

///|
fn three(values : Array[Array[Double]]) -> @phylo.DistanceMatrix {
  { taxa: ["A", "B", "C"], values, }
}

///|
fn rejected(matrix : @phylo.DistanceMatrix) -> @nj.NJError {
  match @nj.neighbor_joining(matrix) {
    Err(error) => error
    Ok(_) => abort("expected explicit NJ error")
  }
}

///|
fn near(actual : Double, expected : Double) -> Unit raise {
  let difference = actual - expected
  let absolute = if difference < 0.0 { -difference } else { difference }
  let magnitude = if expected < 0.0 { -expected } else { expected }
  assert_true(absolute <= 1.0e-10 + 1.0e-12 * magnitude)
}

///|
test "independent additive branches paths split export and unrooted PD guard" {
  let matrix = four([
    [0.0, 3.0, 9.0, 10.0],
    [3.0, 0.0, 10.0, 11.0],
    [9.0, 10.0, 0.0, 7.0],
    [10.0, 11.0, 7.0, 0.0],
  ])
  let report = @nj.neighbor_joining(matrix).unwrap()
  assert_eq(report.tree.rooting(), @phylo.Unrooted)
  assert_eq(report.fitted.values, matrix.values)
  assert_eq(report.max_abs_residual, 0.0)
  assert_eq(report.rms_residual, 0.0)
  let reference = @phylo.PhyloTree::from_newick("[&U]((A:1,B:2):5,C:3,D:4);").unwrap()
  assert_eq(report.tree.rf_distance_unrooted(reference).unwrap().distance, 0)
  let pendant = Map([("A", 1.0), ("B", 2.0), ("C", 3.0), ("D", 4.0)])
  let internal = []
  for node in report.tree.nodes() {
    if node.children.is_empty() {
      assert_eq(node.length.unwrap(), pendant[node.label.unwrap()])
    } else if node.parent is Some(_) {
      internal.push(node.length.unwrap())
    }
  }
  assert_eq(internal, [5.0])
  let exported = @phylo.PhyloTree::from_newick(report.tree.to_newick()).unwrap()
  assert_eq(exported.patristic_matrix().unwrap().values, matrix.values)
  assert_eq(exported.rf_distance_unrooted(report.tree).unwrap().distance, 0)
  assert_true(report.tree.faith_pd(["A"]) is Err(@phylo.RootedTreeRequired))
}

///|
test "independent four-cycle residuals canonical tie and permutation" {
  let matrix = four([
    [0.0, 1.0, 2.0, 1.0],
    [1.0, 0.0, 1.0, 2.0],
    [2.0, 1.0, 0.0, 1.0],
    [1.0, 2.0, 1.0, 0.0],
  ])
  let report = @nj.neighbor_joining(matrix).unwrap()
  assert_eq(report.residuals, [
    [0.0, 0.0, -0.5, 0.5],
    [0.0, 0.0, 0.5, -0.5],
    [-0.5, 0.5, 0.0, 0.0],
    [0.5, -0.5, 0.0, 0.0],
  ])
  assert_eq(report.max_abs_residual, 0.5)
  near(report.rms_residual, (1.0 / 6.0).sqrt())
  let reference = @phylo.PhyloTree::from_newick(
    "[&U]((A:0.5,B:0.5):0.5,C:0.5,D:0.5);",
  ).unwrap()
  assert_eq(report.tree.rf_distance_unrooted(reference).unwrap().distance, 0)
  let reverse : @phylo.DistanceMatrix = {
    taxa: ["D", "C", "B", "A"],
    values: Array::makei(4, i => {
      Array::makei(4, j => matrix.values[3 - i][3 - j])
    }),
  }
  assert_eq(
    @nj.neighbor_joining(reverse).unwrap().tree.to_newick(),
    report.tree.to_newick(),
  )
}

///|
test "three-star negative limbs tiny negatives and numeric overflow" {
  let additive = three([[0.0, 3.0, 4.0], [3.0, 0.0, 5.0], [4.0, 5.0, 0.0]])
  assert_eq(
    @nj.neighbor_joining(additive).unwrap().fitted.values,
    additive.values,
  )
  let error = rejected(
    three([[0.0, 1.0, 1.0], [1.0, 0.0, 3.0], [1.0, 3.0, 0.0]]),
  )
  assert_true(error is @nj.NegativeLimb(["A"], -0.5))
  assert_true(
    rejected(
      four([
        [0.0, 1.0, 1.0, 1.0],
        [1.0, 0.0, 3.0, 3.0],
        [1.0, 3.0, 0.0, 2.0],
        [1.0, 3.0, 2.0, 0.0],
      ]),
    )
    is @nj.NegativeLimb(["A"], -0.5),
  )
  let tiny = 0x1UL.reinterpret_as_double()
  assert_true(
    rejected(
      three([
        [0.0, tiny, tiny],
        [tiny, 0.0, tiny * 3.0],
        [tiny, tiny * 3.0, 0.0],
      ]),
    )
    is @nj.NegativeLimb(_, _),
  )
  let huge = four(
    Array::makei(4, i => {
      Array::makei(4, j => if i == j { 0.0 } else { 1.0e308 })
    }),
  )
  let report = @nj.neighbor_joining(huge).unwrap()
  assert_eq(report.fitted.values, huge.values)
  assert_eq(report.max_abs_residual, 0.0)
}

///|
test "two-tip full path preserves subnormal and quoted exact labels" {
  let tiny = 0x1UL.reinterpret_as_double()
  let report = @nj.neighbor_joining({
    taxa: ["样本🙂", "A_B'"],
    values: [[-0.0, tiny], [tiny, 0.0]],
  }).unwrap()
  assert_eq(report.fitted.taxa, ["A_B'", "样本🙂"])
  assert_eq(report.fitted.values[0][1].reinterpret_as_uint64(), 1UL)
  assert_eq(report.input.values[0][0].reinterpret_as_uint64(), 0UL)
  assert_eq(report.max_abs_residual, 0.0)
  let decoded = @phylo.PhyloTree::from_newick(report.tree.to_newick()).unwrap()
  assert_eq(decoded.taxa(), report.fitted.taxa)
  assert_eq(
    decoded.patristic_matrix().unwrap().values[0][1].reinterpret_as_uint64(),
    1UL,
  )
}

///|
test "zero edges and inclusive 128 limit" {
  let zero = @nj.neighbor_joining(three(Array::makei(3, _ => [0.0, 0.0, 0.0]))).unwrap()
  assert_eq(zero.tree.nodes().length(), 4)
  assert_eq(zero.max_abs_residual, 0.0)
  let zero4 = @nj.neighbor_joining(
    four(Array::makei(4, _ => Array::make(4, 0.0))),
  ).unwrap()
  let star = @phylo.PhyloTree::from_newick("[&U](A:0,B:0,C:0,D:0);").unwrap()
  assert_eq(zero4.tree.nodes().length(), 6)
  assert_eq(zero4.tree.rf_distance_unrooted(star).unwrap().distance, 1)
  let boundary : @phylo.DistanceMatrix = {
    taxa: Array::makei(128, i => "taxon\{i}"),
    values: Array::makei(128, _ => Array::make(128, 0.0)),
  }
  let report = @nj.neighbor_joining(boundary).unwrap()
  assert_eq(report.fitted.taxa.length(), 128)
  assert_eq(report.max_abs_residual, 0.0)
  assert_true(
    rejected({ taxa: Array::make(129, "x"), values: [], })
    is @nj.InvalidSize(129),
  )
  assert_true(rejected({ taxa: [], values: [], }) is @nj.InvalidSize(0))
  assert_true(rejected({ taxa: ["x"], values: [[0.0]], }) is @nj.InvalidSize(1))
}

///|
test "invalid matrix facts retain original indices" {
  assert_true(
    rejected({ taxa: ["B", "A"], values: [[0.0, 1.0]], })
    is @nj.InvalidShape(-1, 2, 1),
  )
  assert_true(
    rejected({ taxa: ["B", "A"], values: [[0.0], [1.0, 0.0]], })
    is @nj.InvalidShape(0, 2, 1),
  )
  assert_true(
    rejected({ taxa: ["", "A"], values: [[0.0, 1.0], [1.0, 0.0]], })
    is @nj.EmptyTaxon(0),
  )
  assert_true(
    rejected({ taxa: ["A", "A"], values: [[0.0, 1.0], [1.0, 0.0]], })
    is @nj.DuplicateTaxon("A"),
  )
  for
    bad in [
      0x7ff0000000000000UL.reinterpret_as_double(),
      0xfff0000000000000UL.reinterpret_as_double(),
      0x7ff8000000000000UL.reinterpret_as_double(),
    ] {
    assert_true(
      rejected({ taxa: ["B", "A"], values: [[0.0, bad], [bad, 0.0]], })
      is @nj.NonFinite(0, 1),
    )
  }
  assert_true(
    rejected({ taxa: ["B", "A"], values: [[0.0, -1.0], [-1.0, 0.0]], })
    is @nj.NegativeDistance(0, 1),
  )
  assert_true(
    rejected({ taxa: ["B", "A"], values: [[1.0, 2.0], [2.0, 0.0]], })
    is @nj.NonzeroDiagonal(0),
  )
  assert_true(
    rejected({
      taxa: ["B", "A"],
      values: [[0.0, 1.0], [1.0000000000000002, 0.0]],
    })
    is @nj.Asymmetric(0, 1),
  )
}

///|
test "JSON matrix to tree and NFC-distinct identities" {
  let report = @nj.from_json(
    "{\"taxa\":[\"Café\",\"Café\"],\"values\":[[0,6],[6,0]]}",
  ).unwrap()
  assert_eq(report.tree.taxa(), ["Café", "Café"])
  assert_eq(report.tree.patristic_distance("Café", "Café").unwrap(), 6.0)
  assert_true(
    @nj.from_json("{\"taxa\":[\"Café\",\"Café\"],\"values\":[[0,6],[6,0]]}")
    is Err(@nj.DuplicateTaxon("Café")),
  )
  assert_true(@nj.from_json("not JSON") is Err(@nj.InvalidJson))
  assert_true(
    @nj.from_json(
      "{\"taxa\":[\"A\",\"B\"],\"values\":[[0,1],[1,0]],\"repair\":true}",
    )
    is Err(@nj.InvalidField("repair")),
  )
  assert_true(
    @nj.from_json("{\"taxa\":[\"A\",1],\"values\":[[0,1],[1,0]]}")
    is Err(@nj.InvalidField("taxa[1]")),
  )
  assert_true(
    @nj.from_json("{\"taxa\":[\"A\",\"B\"],\"values\":[[0,\"1\"],[1,0]]}")
    is Err(@nj.InvalidField("values[0][1]")),
  )
}
