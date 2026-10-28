///|
fn consume(text : String) -> Json {
  let report = match @nj.from_json(text) {
    Ok(report) => report
    Err(error) => return error.to_json()
  }
  let payload = report.to_json()
  match @env.get_env_var("PHYLO_NJ_REFERENCE") {
    None => payload
    Some(newick) => {
      let reference = match @phylo.PhyloTree::from_newick(newick) {
        Ok(tree) => tree
        Err(error) => return @nj.CoreError(error).to_json()
      }
      let comparison = match report.tree.rf_distance_unrooted(reference) {
        Ok(comparison) => comparison
        Err(error) => return @nj.CoreError(error).to_json()
      }
      guard payload is Object(fields) else {
        abort("NJReport must be an object")
      }
      fields["comparison"] = comparison.to_json()
      Json::object(fields)
    }
  }
}

///|
fn input_error(code : String) -> Json {
  Json::object(Map([("ok", false.to_json()), ("error", code.to_json())]))
}

///|
fn input() -> Json {
  match
    (
      @env.get_env_var("PHYLO_NJ_MATRIX_FILE"),
      @env.get_env_var("PHYLO_NJ_MATRIX"),
    ) {
    (Some(_), Some(_)) => input_error("input_source_conflict")
    (Some(""), None) => input_error("empty_matrix_file")
    (Some(path), None) =>
      match read_matrix_file(path) {
        Ok(text) => consume(text)
        Err(error) => error
      }
    (None, Some(text)) => consume(text)
    (None, None) => input_error("missing_matrix")
  }
}

///|
fn main {
  println(input().stringify())
}
