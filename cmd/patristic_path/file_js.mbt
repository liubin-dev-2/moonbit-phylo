///|
extern "js" fn read_tree_bytes(path : String) -> FixedArray[String] =
  #| function(path) {
  #|   if (typeof require !== "function" || typeof process === "undefined" || !process.versions.node) {
  #|     return ["unsupported_file_host", "", ""];
  #|   }
  #|   let bytes;
  #|   try {
  #|     bytes = require("node:fs").readFileSync(path);
  #|   } catch (error) {
  #|     return ["file_read_error", typeof error.code === "string" ? error.code : "IO_ERROR", ""];
  #|   }
  #|   try {
  #|     // Preserve every decoded character, including BOM: Newick decides it.
  #|     return ["", "", new TextDecoder("utf-8", {fatal: true, ignoreBOM: true}).decode(bytes)];
  #|   } catch (_) {
  #|     return ["invalid_utf8", "", ""];
  #|   }
  #| }

///|
fn read_tree_file(path : String) -> Result[String, Json] {
  let result = read_tree_bytes(path)
  if result[0] == "" {
    Ok(result[2])
  } else {
    let fields = Map([("ok", false.to_json()), ("error", result[0].to_json())])
    if result[1] != "" {
      fields["code"] = result[1].to_json()
    }
    Err(Json::object(fields))
  }
}
