///|
fn sample_plan_document() -> @phylo.FaithPDPlanDocument {
  read("((A:1,B:8):3,(C:4,D:5):6)R:999;")
  .faith_pd_plan_document(["A"], ["B", "C", "D"], 2U)
  .unwrap()
}

///|
fn document_with(field : String, value : Json) -> String {
  guard sample_plan_document().to_json() is Object(fields) else {
    abort("object")
  }
  fields[field] = value
  Json::object(fields).stringify()
}

///|
test "plan document snapshots request and replays independent hand totals" {
  let tree = read("((A:1,B:8):3,(C:4,D:5):6)R:999;")
  let baseline = ["A"]
  let candidates = ["D", "A", "C", "B"]
  let saved = tree.faith_pd_plan_document(baseline, candidates, 2U).unwrap()
  baseline[0] = "B"
  candidates[0] = "B"
  assert_eq(saved.baseline_taxa, ["A"])
  assert_eq(saved.candidate_taxa, ["A", "B", "C", "D"])
  let loaded = @phylo.FaithPDPlanDocument::from_json(
    saved.to_json().stringify(),
  ).unwrap()
  assert_eq(loaded.limit, 2U)
  assert_eq(loaded.expected_added_taxa, ["D", "B"])
  assert_eq(loaded.expected_gain, 19.0)
  assert_eq(loaded.expected_step_gains, [11.0, 8.0])
  let (rebuilt, plan) = loaded.replay().unwrap()
  assert_eq(rebuilt.to_newick(), tree.to_newick())
  assert_eq(plan.selected_taxa, ["A", "B", "D"])
  assert_eq(plan.candidate_taxa, ["B", "C", "D"])
  assert_eq(rebuilt.faith_pd(plan.selected_taxa).unwrap().total_length, 23.0)
}

///|
test "plan document Unicode quotes escapes and UTF8 BOM survive interchange" {
  let tree = read(
    "('龙_种':1,'O''Brien':2,'space name':3,'slash\\quote\"':4)R;",
  )
  let saved = tree
    .faith_pd_plan_document(
      ["龙_种"],
      ["O'Brien", "space name", "slash\\quote\""],
      2U,
    )
    .unwrap()
  let loaded = @phylo.FaithPDPlanDocument::from_json(
    "\u{feff}" + saved.to_json().stringify(),
  ).unwrap()
  assert_eq(loaded.baseline_taxa, ["龙_种"])
  assert_eq(loaded.expected_added_taxa, ["slash\\quote\"", "space name"])
  let (tree, plan) = loaded.replay().unwrap()
  assert_true(tree.taxa().contains("O'Brien"))
  assert_eq(plan.gain, 7.0)
}

///|
test "plan document preserves zero and full UInt limit without numeric conversion" {
  let tree = read("(A:1,B:2,C:3);")
  for limit in [0U, 0xffffffffU] {
    let saved = tree
      .faith_pd_plan_document(["A"], ["A", "C", "B"], limit)
      .unwrap()
    let loaded = @phylo.FaithPDPlanDocument::from_json(
      saved.to_json().stringify(),
    ).unwrap()
    assert_eq(loaded.limit, limit)
    let (_, plan) = loaded.replay().unwrap()
    assert_eq(plan.limit, limit)
    assert_eq(plan.added_taxa, if limit == 0U { [] } else { ["C", "B"] })
    guard saved.to_json() is Object(fields) else { abort("object") }
    assert_eq(fields.get("limit"), Some(Json::string(limit.to_string())))
  }
  let padded = @phylo.FaithPDPlanDocument::from_json(
    document_with("limit", "0002".to_json()),
  ).unwrap()
  assert_eq(padded.limit, 2U)
}

///|
test "plan document rejects malformed decimal limits and wrong JSON types" {
  for
    limit in [
      "", "-1", "+2", "2.0", "1e0", " 2", "2 ", "4294967296", "999999999999999999999",
      "二",
    ] {
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(
        document_with("limit", limit.to_json()),
      )
      is Err(@phylo.InvalidField("limit")),
    )
  }
  for value in [(2).to_json(), 2.5.to_json(), Json::null(), true.to_json()] {
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(document_with("limit", value))
      is Err(@phylo.InvalidField("limit")),
    )
  }
}

///|
test "plan document enforces JSON object version required and known fields" {
  for text in ["", "{", "{\"schema\":}", "[] trailing"] {
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(text) is Err(@phylo.InvalidJson),
    )
  }
  for text in ["[]", "null", "true", "1"] {
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(text)
      is Err(@phylo.InvalidField("document")),
    )
  }
  assert_true(
    @phylo.FaithPDPlanDocument::from_json(
      document_with("schema", "v2".to_json()),
    )
    is Err(@phylo.UnsupportedSchema("v2")),
  )
  for
    field in [
      "schema", "tree_newick", "baseline_taxa", "candidate_taxa", "limit", "expected_added_taxa",
      "expected_gain", "expected_step_gains",
    ] {
    guard sample_plan_document().to_json() is Object(fields) else {
      abort("object")
    }
    fields.remove(field)
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(Json::object(fields).stringify())
      is Err(@phylo.InvalidField(name)) &&
      name == field,
    )
  }
  assert_true(
    @phylo.FaithPDPlanDocument::from_json(
      document_with("unexpected", Json::null()),
    )
    is Err(@phylo.InvalidField("unexpected")),
  )
}

///|
test "plan document validates string arrays and finite nonnegative claims" {
  for
    field in [
      "schema", "tree_newick", "baseline_taxa", "candidate_taxa", "expected_added_taxa",
      "expected_gain", "expected_step_gains",
    ] {
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(document_with(field, Json::null()))
      is Err(@phylo.InvalidField(name)) &&
      name == field,
    )
  }
  for field in ["baseline_taxa", "candidate_taxa", "expected_added_taxa"] {
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(document_with(field, [1].to_json()))
      is Err(@phylo.InvalidField(name)) &&
      name == field,
    )
  }
  assert_true(
    @phylo.FaithPDPlanDocument::from_json(
      document_with("expected_gain", (-1.0).to_json()),
    )
    is Err(@phylo.InvalidField("expected_gain")),
  )
  for value in [[-1.0].to_json(), ["1"].to_json()] {
    assert_true(
      @phylo.FaithPDPlanDocument::from_json(
        document_with("expected_step_gains", value),
      )
      is Err(@phylo.InvalidField("expected_step_gains")),
    )
  }
}

///|
test "plan document parsing does not certify altered result claims" {
  let cases = [
    ("expected_added_taxa", ["B", "D"].to_json()),
    ("expected_gain", 18.0.to_json()),
    ("expected_step_gains", [11.0].to_json()),
    ("expected_step_gains", [10.0, 9.0].to_json()),
  ]
  for (field, value) in cases {
    let loaded = @phylo.FaithPDPlanDocument::from_json(
      document_with(field, value),
    ).unwrap()
    assert_true(
      loaded.replay() is Err(@phylo.ClaimMismatch(name)) && name == field,
    )
  }
}

///|
test "plan document replay preserves tree and selection error categories" {
  let invalid_tree = @phylo.FaithPDPlanDocument::from_json(
    document_with("tree_newick", "(A:1,B:2)".to_json()),
  ).unwrap()
  assert_true(
    invalid_tree.replay() is Err(@phylo.TreeError(@phylo.Syntax(_, _))),
  )
  for source in ["(A:1,B:2);", "[&U](A:1,B:2);"] {
    let loaded = @phylo.FaithPDPlanDocument::from_json(
      document_with("tree_newick", source.to_json()),
    ).unwrap()
    assert_true(
      loaded.replay() is Err(@phylo.TreeError(@phylo.RootedTreeRequired)),
    )
  }
  let missing = @phylo.FaithPDPlanDocument::from_json(
    document_with("tree_newick", "[&R](A:1,B,C:3,D:4);".to_json()),
  ).unwrap()
  assert_true(
    missing.replay() is Err(@phylo.TreeError(@phylo.MissingLength(_))),
  )
  let unknown = @phylo.FaithPDPlanDocument::from_json(
    document_with("candidate_taxa", ["Z"].to_json()),
  ).unwrap()
  assert_true(
    unknown.replay() is Err(@phylo.TreeError(@phylo.UnknownTaxon("Z"))),
  )
  for field in ["baseline_taxa", "candidate_taxa"] {
    let duplicate = @phylo.FaithPDPlanDocument::from_json(
      document_with(field, ["A", "A"].to_json()),
    ).unwrap()
    assert_true(
      duplicate.replay()
      is Err(@phylo.TreeError(@phylo.DuplicateSelection("A"))),
    )
  }
}

///|
test "plan document public constructors still require schema and finite claims" {
  let saved = sample_plan_document()
  let wrong_schema = { ..saved, schema: "future", }
  assert_true(wrong_schema.replay() is Err(@phylo.UnsupportedSchema("future")))
  for
    gain in [
      0x7ff0000000000000UL.reinterpret_as_double(),
      0x7ff8000000000000UL.reinterpret_as_double(),
      -1.0,
    ] {
    let bad_total = { ..saved, expected_gain: gain, }
    assert_true(bad_total.replay() is Err(@phylo.InvalidField("expected_gain")))
    let bad_step = { ..saved, expected_step_gains: [gain], }
    assert_true(
      bad_step.replay() is Err(@phylo.InvalidField("expected_step_gains")),
    )
  }
}

///|
test "plan document exporter propagates existing validation before saving" {
  let unknown = @phylo.PhyloTree::from_newick("(A:1,B:2);").unwrap()
  assert_true(
    unknown.faith_pd_plan_document([], [], 0U) is Err(@phylo.RootedTreeRequired),
  )
  let missing = read("(A:1,B);")
  assert_true(
    missing.faith_pd_plan_document([], [], 0U) is Err(@phylo.MissingLength(_)),
  )
  assert_true(
    read("(A:1,B:2);").faith_pd_plan_document([], ["Z"], 0U)
    is Err(@phylo.UnknownTaxon("Z")),
  )
}
