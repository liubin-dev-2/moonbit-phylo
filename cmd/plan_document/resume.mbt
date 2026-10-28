///|
fn resume_plan(text : String, additional_limit : String) -> Json {
  let document = match @phylo.FaithPDPlanDocument::from_json(text) {
    Ok(document) => document
    Err(error) => return document_error(error)
  }
  let (tree, prior) = match document.replay() {
    Ok(result) => result
    Err(error) => return document_error(error)
  }
  let limit = request_limit(additional_limit.to_json()) catch {
    RequestFault(error) => return document_error(error)
  }
  match
    tree.faith_pd_plan_document(
      prior.selected_taxa,
      document.candidate_taxa,
      limit,
    ) {
    Ok(continuation) => continuation.to_json()
    Err(error) => document_error(@phylo.TreeError(error))
  }
}

///|
fn resume_from_env() -> Json {
  guard @env.get_env_var("PHYLO_PLAN_DOCUMENT") is Some(text) else {
    return Json::object(
      Map([("ok", false.to_json()), ("error", "missing_document".to_json())]),
    )
  }
  guard @env.get_env_var("PHYLO_PLAN_ADDITIONAL_LIMIT") is Some(limit) else {
    return Json::object(
      Map([
        ("ok", false.to_json()),
        ("error", "missing_additional_limit".to_json()),
      ]),
    )
  }
  resume_plan(text, limit)
}
