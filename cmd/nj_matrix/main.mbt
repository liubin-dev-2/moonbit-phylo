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
fn main {
  let payload = match @env.get_env_var("PHYLO_NJ_MATRIX") {
    Some(text) => consume(text)
    None =>
      Json::object(
        Map([("ok", false.to_json()), ("error", "missing_matrix".to_json())]),
      )
  }
  println(payload.stringify())
}
