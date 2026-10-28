///|
priv suberror RequestFailure {
  RequestFault(@phylo.PlanDocumentError)
}

///|
fn request_field(
  fields : Map[String, Json],
  key : String,
) -> Json raise RequestFailure {
  guard fields.get(key) is Some(value) else {
    raise RequestFault(@phylo.InvalidField(key))
  }
  value
}

///|
fn request_string(value : Json, key : String) -> String raise RequestFailure {
  guard value is String(text) else {
    raise RequestFault(@phylo.InvalidField(key))
  }
  text
}

///|
fn request_taxa(
  value : Json,
  key : String,
) -> Array[String] raise RequestFailure {
  guard value is Array(items) else {
    raise RequestFault(@phylo.InvalidField(key))
  }
  items.map(item => request_string(item, key))
}

///|
fn request_limit(value : Json) -> UInt raise RequestFailure {
  let text = request_string(value, "limit")
  if text.is_empty() {
    raise RequestFault(@phylo.InvalidField("limit"))
  }
  let mut limit = 0U
  for c in text {
    if c < '0' || c > '9' {
      raise RequestFault(@phylo.InvalidField("limit"))
    }
    let digit = (c.to_int() - 48).reinterpret_as_uint()
    if limit > 429496729U || (limit == 429496729U && digit > 5U) {
      raise RequestFault(@phylo.InvalidField("limit"))
    }
    limit = limit * 10U + digit
  }
  limit
}

///|
fn plan_from_request(
  text : String,
) -> Result[@phylo.FaithPDPlanDocument, @phylo.PlanDocumentError] {
  let body = text.strip_prefix("\u{feff}").unwrap_or(text[:])
  let value = @json.parse(body) catch { _ => return Err(@phylo.InvalidJson) }
  try {
    guard value is Object(fields) else {
      raise RequestFault(@phylo.InvalidField("request"))
    }
    let schema = request_string(request_field(fields, "schema"), "schema")
    if schema != "phylo/faith-pd-greedy-request/v1" {
      raise RequestFault(@phylo.UnsupportedSchema(schema))
    }
    for key, _ in fields {
      match key {
        "schema"
        | "tree_newick"
        | "baseline_taxa"
        | "candidate_taxa"
        | "limit" => ()
        _ => raise RequestFault(@phylo.InvalidField(key))
      }
    }
    let source = request_string(
      request_field(fields, "tree_newick"),
      "tree_newick",
    )
    let baseline = request_taxa(
      request_field(fields, "baseline_taxa"),
      "baseline_taxa",
    )
    let candidates = request_taxa(
      request_field(fields, "candidate_taxa"),
      "candidate_taxa",
    )
    let limit = request_limit(request_field(fields, "limit"))
    let tree = match @phylo.PhyloTree::from_newick(source) {
      Ok(tree) => tree
      Err(error) => return Err(@phylo.TreeError(error))
    }
    match tree.faith_pd_plan_document(baseline, candidates, limit) {
      Ok(document) => Ok(document)
      Err(error) => Err(@phylo.TreeError(error))
    }
  } catch {
    RequestFault(error) => Err(error)
  }
}

///|
fn create_request(text : String) -> Json {
  match plan_from_request(text) {
    Ok(document) => document.to_json()
    Err(error) => document_error(error)
  }
}
