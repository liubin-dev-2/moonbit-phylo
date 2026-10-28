///|
pub(all) enum PlanDocumentError {
  InvalidJson
  InvalidField(String)
  UnsupportedSchema(String)
  TreeError(PhyloError)
  ClaimMismatch(String)
} derive(Debug, Eq)

///|
pub(all) struct FaithPDPlanDocument {
  schema : String
  tree_newick : String
  baseline_taxa : Array[String]
  candidate_taxa : Array[String]
  limit : UInt
  expected_added_taxa : Array[String]
  expected_gain : Double
  expected_step_gains : Array[Double]
} derive(Debug)

///|
let plan_document_schema : String = "phylo/faith-pd-greedy-plan/v1"

///|
priv suberror DocumentFailure {
  DocumentFault(PlanDocumentError)
}

///|
pub impl ToJson for FaithPDPlanDocument with fn to_json(self) {
  Json::object(
    Map([
      ("schema", self.schema.to_json()),
      ("tree_newick", self.tree_newick.to_json()),
      ("baseline_taxa", self.baseline_taxa.to_json()),
      ("candidate_taxa", self.candidate_taxa.to_json()),
      ("limit", self.limit.to_string().to_json()),
      ("expected_added_taxa", self.expected_added_taxa.to_json()),
      ("expected_gain", self.expected_gain.to_json()),
      ("expected_step_gains", self.expected_step_gains.to_json()),
    ]),
  )
}

///|
pub fn PhyloTree::faith_pd_plan_document(
  self : PhyloTree,
  baseline : Array[String],
  candidates : Array[String],
  limit : UInt,
) -> Result[FaithPDPlanDocument, PhyloError] {
  match self.faith_pd_greedy(baseline, candidates, limit) {
    Err(error) => Err(error)
    Ok(plan) => {
      let candidate_taxa = candidates.copy()
      candidate_taxa.sort_by((a, b) => a.lexical_compare(b))
      Ok({
        schema: plan_document_schema,
        tree_newick: self.to_newick(),
        baseline_taxa: plan.baseline_taxa.copy(),
        candidate_taxa,
        limit,
        expected_added_taxa: plan.added_taxa.copy(),
        expected_gain: plan.gain,
        expected_step_gains: plan.steps.map(step => step.gain),
      })
    }
  }
}

///|
fn document_field(
  fields : Map[String, Json],
  key : String,
) -> Json raise DocumentFailure {
  guard fields.get(key) is Some(value) else {
    raise DocumentFault(InvalidField(key))
  }
  value
}

///|
fn document_string(value : Json, key : String) -> String raise DocumentFailure {
  guard value is String(text) else { raise DocumentFault(InvalidField(key)) }
  text
}

///|
fn document_strings(
  value : Json,
  key : String,
) -> Array[String] raise DocumentFailure {
  guard value is Array(items) else { raise DocumentFault(InvalidField(key)) }
  items.map(item => document_string(item, key))
}

///|
fn document_number(value : Json, key : String) -> Double raise DocumentFailure {
  guard value is Number(number, ..) &&
    !number.is_nan() &&
    !number.is_inf() &&
    number >= 0.0 else {
    raise DocumentFault(InvalidField(key))
  }
  number
}

///|
fn document_limit(value : Json) -> UInt raise DocumentFailure {
  let text = document_string(value, "limit")
  if text.is_empty() {
    raise DocumentFault(InvalidField("limit"))
  }
  let mut result = 0U
  for c in text {
    if c < '0' || c > '9' {
      raise DocumentFault(InvalidField("limit"))
    }
    let digit = (c.to_int() - 48).reinterpret_as_uint()
    if result > 429496729U || (result == 429496729U && digit > 5U) {
      raise DocumentFault(InvalidField("limit"))
    }
    result = result * 10U + digit
  }
  result
}

///|
/// Decode structure/version only. Call replay to validate tree semantics and
/// recompute the saved result claims.
pub fn FaithPDPlanDocument::from_json(
  text : String,
) -> Result[FaithPDPlanDocument, PlanDocumentError] {
  let body = text.strip_prefix("\u{feff}").unwrap_or(text[:])
  let value = @json.parse(body) catch { _ => return Err(InvalidJson) }
  try {
    guard value is Object(fields) else {
      raise DocumentFault(InvalidField("document"))
    }
    let schema = document_string(document_field(fields, "schema"), "schema")
    if schema != plan_document_schema {
      raise DocumentFault(UnsupportedSchema(schema))
    }
    for key, _ in fields {
      match key {
        "schema"
        | "tree_newick"
        | "baseline_taxa"
        | "candidate_taxa"
        | "limit"
        | "expected_added_taxa"
        | "expected_gain"
        | "expected_step_gains" => ()
        _ => raise DocumentFault(InvalidField(key))
      }
    }
    let tree_newick = document_string(
      document_field(fields, "tree_newick"),
      "tree_newick",
    )
    let baseline_taxa = document_strings(
      document_field(fields, "baseline_taxa"),
      "baseline_taxa",
    )
    let candidate_taxa = document_strings(
      document_field(fields, "candidate_taxa"),
      "candidate_taxa",
    )
    let limit = document_limit(document_field(fields, "limit"))
    let expected_added_taxa = document_strings(
      document_field(fields, "expected_added_taxa"),
      "expected_added_taxa",
    )
    let expected_gain = document_number(
      document_field(fields, "expected_gain"),
      "expected_gain",
    )
    guard document_field(fields, "expected_step_gains") is Array(items) else {
      raise DocumentFault(InvalidField("expected_step_gains"))
    }
    let expected_step_gains = items.map(item => {
      document_number(item, "expected_step_gains")
    })
    Ok({
      schema,
      tree_newick,
      baseline_taxa,
      candidate_taxa,
      limit,
      expected_added_taxa,
      expected_gain,
      expected_step_gains,
    })
  } catch {
    DocumentFault(error) => Err(error)
  }
}

///|
/// Rebuild the embedded study tree and compare ordered choices, total gain and
/// every step gain. Returned edge IDs belong to the returned tree.
pub fn FaithPDPlanDocument::replay(
  self : FaithPDPlanDocument,
) -> Result[(PhyloTree, FaithPDGreedyReport), PlanDocumentError] {
  if self.schema != plan_document_schema {
    return Err(UnsupportedSchema(self.schema))
  }
  if self.expected_gain.is_nan() ||
    self.expected_gain.is_inf() ||
    self.expected_gain < 0.0 {
    return Err(InvalidField("expected_gain"))
  }
  for gain in self.expected_step_gains {
    if gain.is_nan() || gain.is_inf() || gain < 0.0 {
      return Err(InvalidField("expected_step_gains"))
    }
  }
  let tree = match PhyloTree::from_newick(self.tree_newick) {
    Ok(tree) => tree
    Err(error) => return Err(TreeError(error))
  }
  let plan = match
    tree.faith_pd_greedy(self.baseline_taxa, self.candidate_taxa, self.limit) {
    Ok(plan) => plan
    Err(error) => return Err(TreeError(error))
  }
  if plan.added_taxa != self.expected_added_taxa {
    return Err(ClaimMismatch("expected_added_taxa"))
  }
  if plan.gain != self.expected_gain {
    return Err(ClaimMismatch("expected_gain"))
  }
  if plan.steps.length() != self.expected_step_gains.length() {
    return Err(ClaimMismatch("expected_step_gains"))
  }
  for i, step in plan.steps {
    if step.gain != self.expected_step_gains[i] {
      return Err(ClaimMismatch("expected_step_gains"))
    }
  }
  Ok((tree, plan))
}
