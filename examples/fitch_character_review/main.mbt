///|
fn failure(code : String, detail : String) -> Json {
  Json::object(
    Map([
      ("ok", false.to_json()),
      ("error", code.to_json()),
      ("detail", detail.to_json()),
    ]),
  )
}

///|
fn invalid_state(taxon : String) -> Json {
  Json::object(
    Map([
      ("ok", false.to_json()),
      ("error", "invalid_state".to_json()),
      ("taxon", taxon.to_json()),
      ("detail", "Expected exactly one Unicode character".to_json()),
    ]),
  )
}

///|
fn state_json(state : Char?) -> Json {
  match state {
    Some(state) => state.to_string().to_json()
    None => Json::null()
  }
}

///|
fn domain_failure(
  error : @phylo.PhyloError,
  original : Array[@phylo.NodeRecord],
  root : Int,
  rooting : @phylo.Rooting,
) -> Json {
  let fields = Map([
    ("ok", false.to_json()),
    ("detail", repr(error).to_json()),
    ("original_nodes", original.to_json()),
    ("root_id", root.to_json()),
    ("rooting", rooting.to_json()),
    ("source_unchanged", true.to_json()),
  ])
  match error {
    @phylo.RootedTreeRequired =>
      fields["error"] = "rooted_tree_required".to_json()
    @phylo.TraitMismatch(missing, extra) => {
      fields["error"] = "trait_mismatch".to_json()
      fields["missing_taxa"] = missing.to_json()
      fields["extra_taxa"] = extra.to_json()
    }
    @phylo.UnsupportedTrait(taxon) => {
      fields["error"] = "unsupported_trait".to_json()
      fields["taxon"] = taxon.to_json()
    }
    @phylo.UnaryNotSupported(id) => {
      fields["error"] = "unary_not_supported".to_json()
      fields["node_id"] = id.to_json()
      fields["child_count"] = original[id].children.length().to_json()
    }
    @phylo.PolytomyNotSupported(id, count) => {
      fields["error"] = "polytomy_not_supported".to_json()
      fields["node_id"] = id.to_json()
      fields["child_count"] = count.to_json()
    }
    _ => fields["error"] = "fitch_error".to_json()
  }
  Json::object(fields)
}

///|
// One complete public-package receiving workflow for the library's existing
// single unordered character. It never interprets an alignment or a DNA model.
fn consume() -> Json {
  let text = match @env.get_env_var("PHYLO_FITCH_TREE") {
    Some(text) => text
    None => return failure("missing_tree", "PHYLO_FITCH_TREE")
  }
  let trait_text = match @env.get_env_var("PHYLO_FITCH_TRAITS") {
    Some(text) => text
    None => return failure("missing_traits", "PHYLO_FITCH_TRAITS")
  }
  let tree = match @phylo.PhyloTree::from_newick(text) {
    Ok(tree) => tree
    Err(error) => return failure("parser_error", repr(error))
  }
  let value = @json.parse(trait_text) catch {
    _ => return failure("invalid_traits_json", "PHYLO_FITCH_TRAITS")
  }
  guard value is Object(fields) else {
    return failure("invalid_traits", "Expected a JSON object of states")
  }
  let keys = []
  for taxon, _ in fields {
    keys.push(taxon)
  }
  keys.sort_by((a, b) => a.lexical_compare(b))
  let traits : Map[String, Char] = Map([])
  let trait_strings : Map[String, String] = Map([])
  for taxon in keys {
    guard fields[taxon] is String(state) else { return invalid_state(taxon) }
    let chars = state.to_array()
    guard chars.length() == 1 && chars[0].to_string() == state else {
      return invalid_state(taxon)
    }
    traits[taxon] = chars[0]
    trait_strings[taxon] = state
  }
  let original = tree.nodes()
  let serialized = tree.to_newick()
  let rooting = tree.rooting()
  let trait_snapshot = traits.to_json().stringify()
  let result = tree.fitch_parsimony(traits)
  guard tree.nodes() == original &&
    tree.to_newick() == serialized &&
    tree.rooting() == rooting &&
    traits.to_json().stringify() == trait_snapshot else {
    abort("Fitch receiving query changed original input")
  }
  let report = match result {
    Ok(report) => report
    Err(error) =>
      return domain_failure(error, original, tree.root_id(), rooting)
  }
  let annotations = original.map(node => {
    let observed = if node.children.is_empty() {
      trait_strings[node.label.unwrap()].to_json()
    } else {
      Json::null()
    }
    Json::object(
      Map([
        ("id", node.id.to_json()),
        ("observed", observed),
        (
          "candidate_states",
          report.candidates[node.id].map(c => c.to_string()).to_json(),
        ),
        ("reconstructed_state", state_json(report.assignment[node.id])),
      ]),
    )
  })
  let changes = report.changed_edges.map(edge => {
    let (parent, child) = edge
    Json::object(
      Map([
        ("parent_id", parent.to_json()),
        ("child_id", child.to_json()),
        ("from_state", state_json(report.assignment[parent])),
        ("to_state", state_json(report.assignment[child])),
      ]),
    )
  })
  Json::object(
    Map([
      ("ok", true.to_json()),
      ("root_id", tree.root_id().to_json()),
      ("rooting", rooting.to_json()),
      ("original_nodes", original.to_json()),
      ("source_newick", serialized.to_json()),
      ("traits", trait_strings.to_json()),
      ("parsimony", report.to_json()),
      ("node_annotations", annotations.to_json()),
      ("changes", changes.to_json()),
      ("source_unchanged", true.to_json()),
    ]),
  )
}

///|
fn main {
  println(consume().stringify())
}
