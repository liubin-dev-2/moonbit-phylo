///|
// Complete flow: select, calculate final coverage/gain, then inspect source edges.
fn main {
  let tree = @phylo.PhyloTree::from_newick(
    "[&R]((A:1,B:8):3,(C:4,D:5):6)R:999;",
  ).unwrap()
  let plan = tree.faith_pd_greedy(["A"], ["B", "C", "D"], 2U).unwrap()
  println(plan.to_json().stringify())
  println(tree.faith_pd(plan.selected_taxa).unwrap().to_json().stringify())
  println(
    tree
    .faith_pd_gain(plan.baseline_taxa, plan.added_taxa)
    .unwrap()
    .to_json()
    .stringify(),
  )
  let nodes = tree.nodes()
  for id in plan.edge_ids {
    println(nodes[id].to_json().stringify())
  }
  let rounded = @phylo.PhyloTree::from_newick(
    "[&R](A:10000000000000000,(B:10000000000000000):1)R;",
  ).unwrap()
  println(
    rounded.faith_pd_greedy([], ["A", "B"], 1U).unwrap().to_json().stringify(),
  )
}
