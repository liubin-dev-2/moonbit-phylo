///|
// Compare candidate groups relative to an existing community; no optimization
// or automatic recommendation is implied by these marginal coverage reports.
fn main {
  let tree = @phylo.PhyloTree::from_newick("[&R]((A:1,B:2):3,(C:4,D:5):6):999;").unwrap()
  for additions in [["B"], ["C"], ["D"], ["C", "D"], ["A"]] {
    println(tree.faith_pd_gain(["A"], additions).unwrap().to_json().stringify())
  }
  let large = @phylo.PhyloTree::from_newick("[&R](A:10000000000000000,B:1);").unwrap()
  println(large.faith_pd_gain(["A"], ["B"]).unwrap().to_json().stringify())
}
