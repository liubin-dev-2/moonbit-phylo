///|
// Validate both the current projection and expansion back through its original
// graph witness. Source ID and projected ID spaces remain separate.
fn check_projected_plan(
  source : @phylo.PhyloTree,
  projected : @phylo.TransformResult,
  baseline : Array[String],
  candidates : Array[String],
  limit : UInt,
  order : Array[String],
  expected_gain : UInt64,
  projected_steps : Array[(String, UInt64, Array[(Array[String], Double)])],
  source_steps : Array[(String, UInt64, Array[(Array[String], Double)])],
) -> Unit raise {
  check_mapping(source, projected)
  let old_nodes = source.nodes()
  let nodes = projected.tree.nodes()
  let old_for_new : Array[Int?] = Array::make(nodes.length(), None)
  for old, mapped in projected.witness.old_to_new {
    if mapped is Some(id) {
      old_for_new[id] = Some(old)
    }
  }
  let original = source.to_newick()
  let view = projected.tree.to_newick()
  let plan = projected.tree
    .faith_pd_greedy(baseline, candidates, limit)
    .unwrap()
  let sorted_base = baseline.copy()
  sorted_base.sort_by((a, b) => a.lexical_compare(b))
  let pool = candidates.filter(x => !baseline.contains(x))
  pool.sort_by((a, b) => a.lexical_compare(b))
  let selected = baseline.copy()
  selected.append(order)
  selected.sort_by((a, b) => a.lexical_compare(b))
  assert_eq(plan.baseline_taxa, sorted_base)
  assert_eq(plan.candidate_taxa, pool)
  assert_eq(plan.limit, limit)
  assert_eq(plan.added_taxa, order)
  assert_eq(plan.selected_taxa, selected)
  assert_eq(plan.root_id, projected.tree.root_id())
  assert_eq(plan.gain.reinterpret_as_uint64(), expected_gain)
  assert_eq(plan.steps.length(), projected_steps.length())
  assert_eq(plan.steps.length(), source_steps.length())
  let union_ids = []
  let used = Array::make(nodes.length(), false)
  let source_used = Array::make(old_nodes.length(), false)
  for i, step in plan.steps {
    let (taxon, gain, edges) = projected_steps[i]
    let (old_taxon, old_gain, old_edges) = source_steps[i]
    assert_eq(step.taxon, taxon)
    assert_eq(step.taxon, old_taxon)
    assert_eq(step.gain.reinterpret_as_uint64(), gain)
    assert_eq(step.gain.reinterpret_as_uint64(), old_gain)
    check_greedy_edges(nodes, step.edge_ids, edges)
    let expanded = []
    for id in step.edge_ids {
      assert_true(!used[id])
      used[id] = true
      union_ids.push(id)
      let parent = nodes[id].parent.unwrap()
      let mut current = old_for_new[parent].unwrap()
      for point in projected.witness.edge_paths[id] {
        let old_edge = if old_nodes[point].parent == Some(current) {
          point
        } else {
          assert_eq(old_nodes[current].parent, Some(point))
          current
        }
        assert_true(!source_used[old_edge])
        source_used[old_edge] = true
        expanded.push(old_edge)
        current = point
      }
      assert_eq(current, old_for_new[id].unwrap())
    }
    expanded.sort_by((a, b) => a.compare(b))
    check_greedy_edges(old_nodes, expanded, old_edges)
  }
  union_ids.sort_by((a, b) => a.compare(b))
  assert_eq(plan.edge_ids, union_ids)
  assert_eq(source.to_newick(), original)
  assert_eq(projected.tree.to_newick(), view)
}
