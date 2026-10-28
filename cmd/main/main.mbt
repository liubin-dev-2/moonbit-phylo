///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let a = @phylo.PhyloTree::from_newick("[&R]((A:1,B:2):3,(C:4,D:5):6);").unwrap()
  let b = @phylo.PhyloTree::from_newick("[&R](A,(B,(C,D)));").unwrap()
  println(a.rf_distance_rooted(b).unwrap().to_json().stringify())
  println(a.rf_distance_unrooted(b).unwrap().to_json().stringify())
  println(
    a
    .fitch_parsimony({ "A": '0', "B": '?', "C": '1', "D": '1' })
    .unwrap()
    .to_json()
    .stringify(),
  )
  println(a.patristic_matrix().unwrap().to_json().stringify())
  let reroot = a.midpoint_root().unwrap()
  println(reroot.tree.to_newick())
  println(reroot.witness.to_json().stringify())
  println(a.prune(["A", "C"]).unwrap().tree.to_newick())
}
