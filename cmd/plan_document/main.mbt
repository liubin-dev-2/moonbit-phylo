///|
fn document_error(error : @phylo.PlanDocumentError) -> Json {
  let code = match error {
    @phylo.InvalidJson => "invalid_json"
    @phylo.InvalidField(_) => "invalid_field"
    @phylo.UnsupportedSchema(_) => "unsupported_schema"
    @phylo.TreeError(_) => "tree_error"
    @phylo.ClaimMismatch(_) => "claim_mismatch"
  }
  let fields = Map([
    ("ok", Json::boolean(false)),
    ("error", Json::string(code)),
    ("detail", Json::string(repr(error))),
  ])
  match error {
    @phylo.InvalidField(field) | @phylo.ClaimMismatch(field) =>
      fields["field"] = Json::string(field)
    _ => ()
  }
  Json::object(fields)
}

///|
fn review(text : String) -> Json {
  let document = match @phylo.FaithPDPlanDocument::from_json(text) {
    Ok(document) => document
    Err(error) => return document_error(error)
  }
  let (tree, plan) = match document.replay() {
    Ok(result) => result
    Err(error) => return document_error(error)
  }
  Json::object(
    Map([
      ("schema", Json::string("phylo/faith-pd-greedy-review/v1")),
      ("ok", Json::boolean(true)),
      ("document", document.to_json()),
      ("plan", plan.to_json()),
      ("nodes", tree.nodes().to_json()),
    ]),
  )
}

///|
fn main {
  if @env.args().contains("review-chain") {
    println(review_chain_from_env().stringify())
  } else if @env.args().contains("resume") {
    println(resume_from_env().stringify())
  } else if @env.args().contains("create") {
    match @env.get_env_var("PHYLO_PLAN_REQUEST") {
      Some(text) => println(create_request(text).stringify())
      None =>
        println(
          Json::object(
            Map([
              ("ok", false.to_json()),
              ("error", "missing_request".to_json()),
            ]),
          ).stringify(),
        )
    }
  } else if @env.args().contains("review") {
    match @env.get_env_var("PHYLO_PLAN_DOCUMENT") {
      Some(text) => println(review(text).stringify())
      None =>
        println(
          Json::object(
            Map([
              ("ok", Json::boolean(false)),
              ("error", Json::string("missing_document")),
            ]),
          ).stringify(),
        )
    }
  } else {
    let tree = @phylo.PhyloTree::from_newick(
      "[&R]((A:1,B:8):3,(C:4,D:5):6)R:999;",
    ).unwrap()
    println(
      tree
      .faith_pd_plan_document(["A"], ["B", "C", "D"], 2U)
      .unwrap()
      .to_json()
      .stringify(),
    )
  }
}
