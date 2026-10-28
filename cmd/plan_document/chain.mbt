///|
fn chain_stage_failure(index : Int, error : @phylo.PlanDocumentError) -> Json {
  Json::object(
    Map([
      ("ok", false.to_json()),
      ("error", "stage_failed".to_json()),
      ("stage_index", index.to_json()),
      ("cause", document_error(error)),
    ]),
  )
}

///|
fn chain_mismatch(index : Int, field : String) -> Json {
  Json::object(
    Map([
      ("ok", false.to_json()),
      ("error", "chain_mismatch".to_json()),
      ("stage_index", index.to_json()),
      ("field", field.to_json()),
    ]),
  )
}

///|
fn review_chain(text : String) -> Json {
  let body = text.strip_prefix("\u{feff}").unwrap_or(text[:])
  let value = @json.parse(body) catch {
    _ => return document_error(@phylo.InvalidJson)
  }
  guard value is Array(items) && !items.is_empty() else {
    return document_error(@phylo.InvalidField("chain"))
  }
  let mut origin_tree : @phylo.PhyloTree? = None
  let mut source = ""
  let mut origin_baseline : Array[String] = []
  let mut pool : Array[String] = []
  let mut previous_selected : Array[String] = []
  let documents : Array[Json] = []
  let stage_added_taxa : Array[Array[String]] = []
  let stage_gains : Array[Double] = []
  for index, item in items {
    let document = match
      @phylo.FaithPDPlanDocument::from_json(item.stringify()) {
      Ok(document) => document
      Err(error) => return chain_stage_failure(index, error)
    }
    let (tree, plan) = match document.replay() {
      Ok(result) => result
      Err(error) => return chain_stage_failure(index, error)
    }
    let current_source = tree.to_newick()
    let current_pool = document.candidate_taxa.copy()
    current_pool.sort_by((a, b) => a.lexical_compare(b))
    if index == 0 {
      origin_tree = Some(tree)
      source = current_source
      origin_baseline = plan.baseline_taxa.copy()
      pool = current_pool
    } else {
      if current_source != source {
        return chain_mismatch(index, "tree_newick")
      }
      if current_pool != pool {
        return chain_mismatch(index, "candidate_taxa")
      }
      if plan.baseline_taxa != previous_selected {
        return chain_mismatch(index, "baseline_taxa")
      }
    }
    documents.push(document.to_json())
    stage_added_taxa.push(plan.added_taxa)
    stage_gains.push(plan.gain)
    previous_selected = plan.selected_taxa
  }
  let origin = origin_tree.unwrap()
  let cumulative = match
    origin.faith_pd_gain(origin_baseline, previous_selected) {
    Ok(report) =>
      Json::object(Map([("ok", true.to_json()), ("report", report.to_json())]))
    Err(error) => document_error(@phylo.TreeError(error))
  }
  Json::object(
    Map([
      ("schema", "phylo/faith-pd-greedy-chain-review/v1".to_json()),
      ("ok", true.to_json()),
      ("stage_count", items.length().to_json()),
      ("tree_newick", source.to_json()),
      ("origin_baseline_taxa", origin_baseline.to_json()),
      ("stage_added_taxa", stage_added_taxa.to_json()),
      ("stage_gains", stage_gains.to_json()),
      ("final_selected_taxa", previous_selected.to_json()),
      ("documents", documents.to_json()),
      ("cumulative", cumulative),
      ("nodes", origin.nodes().to_json()),
    ]),
  )
}

///|
fn review_chain_from_env() -> Json {
  match @env.get_env_var("PHYLO_PLAN_CHAIN") {
    Some(text) => review_chain(text)
    None =>
      Json::object(
        Map([("ok", false.to_json()), ("error", "missing_chain".to_json())]),
      )
  }
}
