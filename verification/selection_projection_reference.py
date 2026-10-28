"""Bounded pruning/projection facts from independent DendroPy suppression.

Reads cached independent selection facts; no old generator or runtime source.
"""
from pathlib import Path
from fractions import Fraction
import argparse
import hashlib
import json
import struct
import dendropy

ROOT = Path(__file__).resolve().parents[1]

def bits(value):
    return struct.pack('>d', float(value)).hex()

def strings(values):
    return '[' + ', '.join(json.dumps(x, ensure_ascii=False) for x in values) + ']'

def edge_literal(edges):
    return '[' + ', '.join('(' + strings(e['descendant_taxa']) + ', 0x' + bits(e['length']) + 'UL.reinterpret_as_double())' for e in edges) + ']'

def step_literal(steps):
    return '[' + ', '.join('(' + json.dumps(s['taxon'], ensure_ascii=False) + ', 0x' + s['gain_bits'] + 'UL, ' + edge_literal(s['edges']) + ')' for s in steps) + ']'

def project(row):
    tree = dendropy.Tree.get(data=row['newick'], schema='newick', rooting='force-rooted', preserve_underscores=True)
    assert len(tree.seed_node.child_nodes()) >= 2
    tree.suppress_unifurcations()
    edges = [{'descendant_taxa': sorted(leaf.taxon.label for leaf in node.leaf_iter()), 'length': float(node.edge.length)}
             for node in tree.preorder_node_iter() if node.parent_node is not None]
    old = set(row['baseline']); steps = []
    for original in row['steps']:
        taxon = original['taxon']
        new_edges = [e for e in edges if taxon in e['descendant_taxa'] and not old.intersection(e['descendant_taxa'])]
        exact = sum((Fraction.from_float(e['length']) for e in new_edges), Fraction(0))
        assert exact == Fraction(original['exact_gain'])
        steps.append({'taxon': taxon, 'gain_bits': bits(exact), 'exact_gain': str(exact), 'edges': new_edges})
        old.add(taxon)
    return {'source': row, 'projected_edges': edges, 'projected_steps': steps}

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--receipt', type=Path); args = parser.parse_args()
    source = ROOT / 'testdata/diversity-greedy-golden.json'
    rows = {x['name']: x for x in json.loads(source.read_text(encoding='utf-8'))['fixtures']}
    names = ['base-0-limit-2', 'base-5-limit-2', 'topology-2-0-3', 'real-1']
    cases = [project(rows[name]) for name in names]
    lines = ['///|', 'test "projection audit compacted plans trace original source edges" {']
    for i, case in enumerate(cases):
        row = case['source']; suffix = str(i)
        lines.append('  let source_' + suffix + ' = read(' + json.dumps(row['newick'], ensure_ascii=False) + ')')
        lines.append('  let projected_' + suffix + ' = source_' + suffix + '.prune(source_' + suffix + '.taxa()).unwrap()')
        lines.append('  check_projected_plan(source_' + suffix + ', projected_' + suffix + ', ' + strings(row['baseline']) + ', ' + strings(row['candidates']) + ', ' + str(row['limit']) + 'U, ' + strings(row['order']) + ', 0x' + row['gain_bits'] + 'UL, ' + step_literal(case['projected_steps']) + ', ' + step_literal(row['steps']) + ')')
    lines += ['}', '', '///|', 'test "projection audit saved projection uses its own reloaded edge IDs" {']
    for i, case in enumerate(cases):
        row = case['source']; suffix = str(i)
        lines.append('  let source_' + suffix + ' = read(' + json.dumps(row['newick'], ensure_ascii=False) + ')')
        lines.append('  let projected_' + suffix + ' = source_' + suffix + '.prune(source_' + suffix + '.taxa()).unwrap()')
        lines.append('  let loaded_' + suffix + ' = @phylo.PhyloTree::from_newick(projected_' + suffix + '.tree.to_newick()).unwrap()')
        lines.append('  check_pd_greedy(loaded_' + suffix + ', ' + strings(row['baseline']) + ', ' + strings(row['candidates']) + ', ' + str(row['limit']) + 'U, ' + strings(row['order']) + ', 0x' + row['gain_bits'] + 'UL, ' + step_literal(case['projected_steps']) + ')')
    lines += ['}', '', '///|', 'test "projection audit compression has the documented Double ranking boundary" {',
              '  let source = read("(A:10000000000000000,(B:10000000000000000):1)R;")',
              '  let projected = source.prune(source.taxa()).unwrap()',
              '  let before = source.faith_pd_greedy([], ["A", "B"], 1U).unwrap()',
              '  let after = projected.tree.faith_pd_greedy([], ["A", "B"], 1U).unwrap()',
              '  assert_eq(before.added_taxa, ["B"])', '  assert_eq(after.added_taxa, ["A"])',
              '  assert_eq(before.gain, 10000000000000000.0)', '  assert_eq(after.gain, before.gain)',
              '  check_mapping(source, projected)', '}', '']
    # The hand-audited graph expansion helper is appended by its separate source.
    (ROOT / 'selection_projection_cases_test.mbt').write_text('\n'.join(lines), encoding='utf-8')
    real = rows['real-1']
    main = ['///|', '// Projection is a review view; precision-sensitive planning stays on the source tree.', 'fn main {',
            '  let source = @phylo.PhyloTree::from_newick(' + json.dumps(real['newick']) + ', rooted=true).unwrap()',
            '  let projected = source.prune(source.taxa()).unwrap()',
            '  let loaded = @phylo.PhyloTree::from_newick(projected.tree.to_newick()).unwrap()',
            '  let baseline = ' + strings(real['baseline']), '  let candidates = ' + strings(real['candidates']),
            '  println(projected.witness.to_json().stringify())',
            '  println(projected.tree.faith_pd_greedy(baseline, candidates, 3U).unwrap().to_json().stringify())',
            '  println(loaded.faith_pd_greedy(baseline, candidates, 3U).unwrap().to_json().stringify())',
            '  println(source.nodes().to_json().stringify())', '  println(projected.tree.nodes().to_json().stringify())',
            '  println(loaded.nodes().to_json().stringify())',
            '  let numeric = @phylo.PhyloTree::from_newick("[&R](A:10000000000000000,(B:10000000000000000):1)R;").unwrap()',
            '  let rounded = numeric.prune(numeric.taxa()).unwrap()',
            '  println(numeric.faith_pd_greedy([], ["A", "B"], 1U).unwrap().to_json().stringify())',
            '  println(rounded.tree.faith_pd_greedy([], ["A", "B"], 1U).unwrap().to_json().stringify())',
            '  println(numeric.nodes().to_json().stringify())', '  println(rounded.tree.nodes().to_json().stringify())',
            '  println(rounded.witness.to_json().stringify())', '}', '']
    target = ROOT / 'cmd/selection_projection/main.mbt'; target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('\n'.join(main), encoding='utf-8')
    receipt = {'dendropy': dendropy.__version__, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
               'cases': cases, 'projection_cases': 4, 'reload_cases': 4, 'precision_cases': 1,
               'exact_source_B': str(Fraction.from_float(1e16) + 1), 'rounded_projected_B': 1e16,
               'classification': 'projection invariants plus existing Double precision boundary; no runtime defect assumed',
               'old_generators_replayed': False, 'runtime_API_changes': False}
    if args.receipt: args.receipt.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in receipt.items() if k != 'cases'}, ensure_ascii=False))

if __name__ == '__main__':
    main()
