///|
/// Incremental single-tree reader. Failed readers remain failed; finish consumes the reader.
pub struct NewickReader {
  arena : Array[Node]
  stack : Array[Int]
  comments : Array[String]
  token : StringBuilder
  comment : StringBuilder
  requested : Rooting
  mut rooting : Rooting
  mut current : Int?
  mut expecting : Bool
  mut need_length : Bool
  mut quoted : Bool
  mut quote_pending : Bool
  mut comment_depth : Int
  mut done : Bool
  mut closed : Bool
  mut position : Int
  mut failure : PhyloError?
}

///|
pub fn NewickReader::NewickReader(rooted? : Bool) -> NewickReader {
  let mode = match rooted {
    Some(true) => Rooted
    Some(false) => Unrooted
    None => Unknown
  }
  {
    arena: [],
    stack: [],
    comments: [],
    token: StringBuilder(),
    comment: StringBuilder(),
    requested: mode,
    rooting: mode,
    current: None,
    expecting: true,
    need_length: false,
    quoted: false,
    quote_pending: false,
    comment_depth: 0,
    done: false,
    closed: false,
    position: 0,
    failure: None,
  }
}

///|
fn syntax(r : NewickReader, message : String) -> Unit raise Failure {
  raise Fault(Syntax(r.position, message))
}

///|
fn add_node(r : NewickReader, label : String?) -> Int {
  let parent = r.stack.last()
  let id = r.arena.length()
  r.arena.push(new_node(parent, label))
  if parent is Some(p) {
    r.arena[p].children.push(id)
  }
  id
}

///|
fn emit_token(
  r : NewickReader,
  text : String,
  quoted : Bool,
) -> Unit raise Failure {
  if r.done {
    syntax(r, "trailing token after semicolon")
  }
  if r.need_length {
    if quoted {
      syntax(r, "quoted branch length")
    }
    // Underflow may round an authored negative decimal to -0.0. Enforce
    // nonnegativity before that sign information disappears; signed zero
    // itself remains legal. Exponent digits do not make a zero mantissa nonzero.
    if text[0] == '-' {
      for c in text {
        if c == 'e' || c == 'E' {
          break
        }
        if c >= '1' && c <= '9' {
          raise Fault(InvalidLength(r.position, text))
        }
      }
    }
    let x = @strings.parse_double(text[:]) catch {
      _ => raise Fault(InvalidLength(r.position, text))
    }
    if x.is_nan() || x.is_inf() || x < 0.0 {
      raise Fault(InvalidLength(r.position, text))
    }
    r.arena[r.current.unwrap()].length = Some(x)
    r.need_length = false
  } else {
    let name = if quoted { text } else { text.replace_all(old="_", new=" ") }
    if r.expecting {
      r.current = Some(add_node(r, Some(name)))
      r.expecting = false
    } else {
      guard r.current is Some(n) else {
        syntax(r, "label without node")
        return
      }
      if r.arena[n].label is Some(_) || r.arena[n].length is Some(_) {
        syntax(r, "unexpected second node label")
      }
      r.arena[n].label = Some(name)
    }
  }
}

///|
fn flush_token(r : NewickReader) -> Unit raise Failure {
  if !r.token.is_empty() {
    let s = r.token.to_string()
    r.token.reset()
    emit_token(r, s, false)
  }
}

///|
fn accept_comment(r : NewickReader) -> Unit raise Failure {
  let s = r.comment.to_string()
  r.comment.reset()
  if r.done {
    r.comments.push(s)
  } else if r.arena.is_empty() && (s == "&R" || s == "&U") {
    let flag = if s == "&R" { Rooted } else { Unrooted }
    if r.rooting != Unknown && r.rooting != flag {
      raise Fault(RootingConflict)
    }
    r.rooting = flag
  } else if r.current is Some(n) {
    r.arena[n].comments.push(s)
  } else {
    r.comments.push(s)
  }
}

///|
fn accept_char(r : NewickReader, c : Char) -> Unit raise Failure {
  if r.comment_depth > 0 {
    if c == '[' {
      r.comment_depth = r.comment_depth + 1
    }
    if c == ']' {
      r.comment_depth = r.comment_depth - 1
    }
    if r.comment_depth == 0 {
      accept_comment(r)
    } else {
      r.comment.write_char(c)
    }
    return
  }
  if r.quoted {
    if r.quote_pending {
      if c == '\'' {
        r.token.write_char(c)
        r.quote_pending = false
        return
      }
      let s = r.token.to_string()
      r.token.reset()
      r.quoted = false
      r.quote_pending = false
      emit_token(r, s, true)
    } else {
      if c == '\'' {
        r.quote_pending = true
      } else {
        r.token.write_char(c)
      }
      return
    }
  }
  if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
    flush_token(r)
    return
  }
  if c == '[' {
    flush_token(r)
    r.comment_depth = 1
    return
  }
  if r.done {
    syntax(r, "trailing input after single tree")
  }
  match c {
    '\'' => {
      if !r.token.is_empty() {
        syntax(r, "quote within unquoted token")
      }
      r.quoted = true
    }
    '(' => {
      flush_token(r)
      if !r.expecting {
        syntax(r, "unexpected opening parenthesis")
      }
      let id = add_node(r, None)
      r.stack.push(id)
      r.current = None
    }
    ',' => {
      flush_token(r)
      if r.expecting || r.need_length || r.stack.is_empty() {
        syntax(r, "missing child or length")
      }
      r.expecting = true
      r.current = None
    }
    ')' => {
      flush_token(r)
      if r.expecting || r.need_length || r.stack.is_empty() {
        syntax(r, "unmatched or empty group")
      }
      r.current = r.stack.pop()
      r.expecting = false
    }
    ':' => {
      flush_token(r)
      if r.expecting || r.need_length {
        syntax(r, "length without node")
      }
      guard r.current is Some(n) else {
        syntax(r, "missing node")
        return
      }
      if r.arena[n].length is Some(_) {
        syntax(r, "repeated length")
      }
      r.need_length = true
    }
    ';' => {
      flush_token(r)
      if r.expecting || r.need_length || !r.stack.is_empty() {
        syntax(r, "unfinished tree")
      }
      r.done = true
    }
    ']' => syntax(r, "unmatched comment close")
    _ => r.token.write_char(c)
  }
}

///|
pub fn NewickReader::feed(
  self : NewickReader,
  chunk : String,
) -> Result[Unit, PhyloError] {
  if self.failure is Some(e) {
    return Err(e)
  }
  if self.closed {
    return Err(Syntax(self.position, "reader already finished"))
  }
  try {
    for c in chunk {
      self.position = self.position + 1
      accept_char(self, c)
    }
    Ok(())
  } catch {
    Fault(e) => {
      self.failure = Some(e)
      Err(e)
    }
  }
}

///|
pub fn NewickReader::finish(
  self : NewickReader,
) -> Result[PhyloTree, PhyloError] {
  if self.failure is Some(e) {
    return Err(e)
  }
  if self.closed {
    return Err(Syntax(self.position, "reader already finished"))
  }
  self.closed = true
  if !self.done || self.quoted || self.comment_depth > 0 {
    return Err(Syntax(self.position, "incomplete single tree"))
  }
  let tree = PhyloTree::{
    arena: self.arena,
    root: 0,
    rooting: self.rooting,
    comments: self.comments,
  }
  let seen : Map[String, Bool] = Map([])
  for id, n in tree.arena {
    if n.children.is_empty() {
      guard n.label is Some(label) && label != "" else {
        return Err(AnonymousTaxon(id))
      }
      if seen.contains(label) {
        return Err(DuplicateTaxon(label))
      }
      seen[label] = true
    }
  }
  Ok(tree)
}

///|
pub fn PhyloTree::from_newick(
  s : String,
  rooted? : Bool,
) -> Result[PhyloTree, PhyloError] {
  let reader = match rooted {
    Some(x) => NewickReader(rooted=x)
    None => NewickReader()
  }
  match reader.feed(s) {
    Err(e) => Err(e)
    Ok(_) => reader.finish()
  }
}

///|
fn quote_label(s : String) -> String {
  "'" + s.replace_all(old="'", new="''") + "'"
}

///|
pub fn PhyloTree::to_newick(self : PhyloTree) -> String {
  let out = StringBuilder()
  match self.rooting {
    Rooted => out.write_string("[&R]")
    Unrooted => out.write_string("[&U]")
    Unknown => ()
  }
  // Events: 0=node open; 1=node suffix; 2=comma.
  let stack = [(0, self.root)]
  while !stack.is_empty() {
    let (kind, id) = stack.pop().unwrap()
    let n = self.arena[id]
    if kind == 2 {
      out.write_string(",")
    } else if kind == 1 {
      if !n.children.is_empty() {
        out.write_string(")")
      }
      if n.label is Some(s) {
        out.write_string(quote_label(s))
      }
      if n.length is Some(x) {
        out.write_string(":" + x.to_string())
      }
      for c in n.comments {
        out.write_string("[" + c + "]")
      }
    } else {
      stack.push((1, id))
      if !n.children.is_empty() {
        out.write_string("(")
        for i = n.children.length() - 1; i >= 0; i = i - 1 {
          stack.push((0, n.children[i]))
          if i > 0 {
            stack.push((2, id))
          }
        }
      }
    }
  }
  out.write_string(";")
  // Tree-level opaque comments must not become leading rooting directives.
  // Trailing comments are unambiguously tree-scoped in this single-tree API.
  for c in self.comments {
    out.write_string("[" + c + "]")
  }
  out.to_string()
}
