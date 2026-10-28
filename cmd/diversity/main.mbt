///|
// Same species count, different evolutionary coverage; root stem is excluded.
fn main {
  let tree = @phylo.PhyloTree::from_newick("[&R]((A:1,B:2):3,(C:4,D:5):6):999;").unwrap()
  for community in [["A", "B"], ["A", "C"], ["A"], []] {
    println(tree.faith_pd(community).unwrap().to_json().stringify())
  }
}
