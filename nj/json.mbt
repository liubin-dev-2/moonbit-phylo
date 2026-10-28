///|
fn field(fields : Map[String, Json], key : String) -> Json raise NJFailure {
  match fields.get(key) {
    Some(value) => value
    None => raise NJFault(InvalidField(key))
  }
}

///|
/// Decode exactly {taxa, values}, then run the same typed matrix validation.
pub fn from_json(text : String) -> Result[NJReport, NJError] {
  let body = text.strip_prefix("\u{feff}").unwrap_or(text[:])
  let value = @json.parse(body) catch { _ => return Err(InvalidJson) }
  try {
    guard value is Object(fields) else { raise NJFault(InvalidField("matrix")) }
    for key, _ in fields {
      if key != "taxa" && key != "values" {
        raise NJFault(InvalidField(key))
      }
    }
    guard field(fields, "taxa") is Array(names) else {
      raise NJFault(InvalidField("taxa"))
    }
    let taxa = names.mapi((i, item) => {
      guard item is String(name) else {
        raise NJFault(InvalidField("taxa[\{i}]"))
      }
      name
    })
    guard field(fields, "values") is Array(rows) else {
      raise NJFault(InvalidField("values"))
    }
    let values = rows.mapi((i, row) => {
      guard row is Array(items) else {
        raise NJFault(InvalidField("values[\{i}]"))
      }
      items.mapi((j, item) => {
        guard item is Number(number, ..) else {
          raise NJFault(InvalidField("values[\{i}][\{j}]"))
        }
        number
      })
    })
    neighbor_joining({ taxa, values, })
  } catch {
    NJFault(error) => Err(error)
  }
}

///|
pub impl ToJson for NJReport with fn to_json(self) {
  Json::object(
    Map([
      ("schema", "phylo/nj-matrix/v1".to_json()),
      ("ok", true.to_json()),
      ("rooting", "unrooted".to_json()),
      ("newick", self.tree.to_newick().to_json()),
      ("nodes", self.tree.nodes().to_json()),
      ("input", self.input.to_json()),
      ("fitted", self.fitted.to_json()),
      ("residuals", self.residuals.to_json()),
      ("max_abs_residual", self.max_abs_residual.to_json()),
      ("rms_residual", self.rms_residual.to_json()),
    ]),
  )
}

///|
pub impl ToJson for NJError with fn to_json(self) {
  let code = match self {
    InvalidJson => "invalid_json"
    InvalidField(_) => "invalid_field"
    InvalidSize(_) => "invalid_size"
    InvalidShape(_, _, _) => "invalid_shape"
    EmptyTaxon(_) => "empty_taxon"
    DuplicateTaxon(_) => "duplicate_taxon"
    NonFinite(_, _) => "non_finite"
    NegativeDistance(_, _) => "negative_distance"
    NonzeroDiagonal(_) => "nonzero_diagonal"
    Asymmetric(_, _) => "asymmetric"
    NumericOverflow(_) => "numeric_overflow"
    NegativeLimb(_, _) => "negative_limb"
    CoreError(_) => "core_error"
  }
  let fields = Map([
    ("ok", false.to_json()),
    ("error", code.to_json()),
    ("detail", repr(self).to_json()),
  ])
  match self {
    InvalidField(key) => fields["field"] = key.to_json()
    InvalidSize(size) => fields["size"] = size.to_json()
    InvalidShape(row, expected, actual) => {
      fields["row"] = row.to_json()
      fields["expected"] = expected.to_json()
      fields["actual"] = actual.to_json()
    }
    EmptyTaxon(index) | NonzeroDiagonal(index) =>
      fields["index"] = index.to_json()
    DuplicateTaxon(name) => fields["taxon"] = name.to_json()
    NonFinite(row, col) | NegativeDistance(row, col) | Asymmetric(row, col) => {
      fields["row"] = row.to_json()
      fields["column"] = col.to_json()
    }
    NumericOverflow(stage) => fields["stage"] = stage.to_json()
    NegativeLimb(taxa, length) => {
      fields["taxa"] = taxa.to_json()
      fields["length"] = length.to_json()
      fields["length_bits"] = length
        .reinterpret_as_uint64()
        .to_string()
        .to_json()
    }
    _ => ()
  }
  Json::object(fields)
}
