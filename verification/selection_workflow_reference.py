"""Bounded rotation/save/resume audit from sealed independent selection facts.

Uses the existing pinned Biopython only to rotate representations. It checks
branch facts before emitting tests; no runtime implementation or old generator.
"""
from pathlib import Path
from fractions import Fraction
from collections import Counter
import argparse
import hashlib
import io
import json
import struct

import Bio
from Bio import Phylo

ROOT = Path(__file__).resolve().parents[1]

def bits(value):
    return struct.pack('>d', float(value)).hex()

def strings(values):
    return '[' + ', '.join(json.dumps(x, ensure_ascii=False) for x in values) + ']'

def step_literal(steps):
    out = []
    for step in steps:
        edges = '[' + ', '.join('(' + strings(e['descendant_taxa']) + ', 0x' + bits(e['length']) + 'UL.reinterpret_as_double())' for e in step['edges']) + ']'
        out.append('(' + json.dumps(step['taxon'], ensure_ascii=False) + ', 0x' + step['gain_bits'] + 'UL, ' + edges + ')')
    return '[' + ', '.join(out) + ']'

def check(tree, baseline, candidates, limit, order, gain, steps):
    return '  check_pd_greedy(' + tree + ', ' + strings(baseline) + ', ' + strings(candidates) + ', ' + str(limit) + 'U, ' + strings(order) + ', 0x' + gain + 'UL, ' + step_literal(steps) + ')'

def signature(tree):
    return Counter((tuple(sorted(t.name for t in node.get_terminals())), bits(node.branch_length))
                   for node in tree.find_clades() if node is not tree.root)

def rotated(text):
    tree = Phylo.read(io.StringIO(text), 'newick')
    def emit(node):
        body = '(' + ','.join(emit(child) for child in reversed(node.clades)) + ')' if node.clades else ''
        label = node.name
        if label is None and node.confidence is not None:
            label = format(node.confidence, '.17g')
        if label is not None:
            body += "'" + label.replace("'", "''") + "'"
        if node.branch_length is not None:
            body += ':' + format(node.branch_length, '.17g')
        return body
    out = '[&R]' + emit(tree.root) + ';'
    assert signature(Phylo.read(io.StringIO(out), 'newick')) == signature(tree)
    return out

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--receipt', type=Path)
    args = parser.parse_args()
    source = ROOT / 'testdata/diversity-greedy-golden.json'
    facts = ROOT / 'testdata/diversity-golden.json'
    rows = {x['name']: x for x in json.loads(source.read_text(encoding='utf-8'))['fixtures']}
    names = ['base-0-limit-2', 'base-5-limit-2', 'topology-1-0-3', 'topology-2-1-4', 'real-1', 'exact-comparison']
    seeds = [rows[name] for name in names]
    lines = ['///|', 'test "selection audit rotated branches and permuted inputs preserve semantic plans" {']
    for i, row in enumerate(seeds):
        lines.append('  let tree_' + str(i) + ' = @phylo.PhyloTree::from_newick(' + json.dumps(rotated(row['newick']), ensure_ascii=False) + ').unwrap()')
        lines.append(check('tree_' + str(i), row['baseline'][::-1], row['candidates'][::-1], row['limit'], row['order'], row['gain_bits'], row['steps']))
    lines += ['}', '', '///|', 'test "selection audit Newick save reload preserves semantic plans" {']
    for i, row in enumerate(seeds):
        lines.append('  let saved_' + str(i) + ' = read(' + json.dumps(row['newick'], ensure_ascii=False) + ').to_newick()')
        lines.append('  let loaded_' + str(i) + ' = @phylo.PhyloTree::from_newick(saved_' + str(i) + ').unwrap()')
        lines.append(check('loaded_' + str(i), row['baseline'], row['candidates'], row['limit'], row['order'], row['gain_bits'], row['steps']))
    lines += ['}', '', '///|', 'test "selection audit saved prefixes resume the full plan suffix" {']
    resumes = 0
    for i, row in enumerate(seeds):
        for prefix in range(len(row['order']) + 1):
            suffix = f'{i}_{prefix}'
            lines.append('  let tree_' + suffix + ' = read(' + json.dumps(row['newick'], ensure_ascii=False) + ')')
            lines.append('  let prefix_' + suffix + ' = tree_' + suffix + '.faith_pd_greedy(' + strings(row['baseline']) + ', ' + strings(row['candidates']) + ', ' + str(prefix) + 'U).unwrap()')
            lines.append('  assert_eq(prefix_' + suffix + '.added_taxa, ' + strings(row['order'][:prefix]) + ')')
            lines.append('  assert_eq(prefix_' + suffix + '.selected_taxa, ' + strings(sorted(row['baseline'] + row['order'][:prefix])) + ')')
            lines.append('  let restored_' + suffix + ' = @phylo.PhyloTree::from_newick(tree_' + suffix + '.to_newick()).unwrap()')
            remaining = row['steps'][prefix:]
            gain = bits(sum((Fraction(x['exact_gain']) for x in remaining), Fraction(0)))
            call = check('restored_' + suffix, [], row['candidates'], row['limit'] - prefix, row['order'][prefix:], gain, remaining)
            call = call.replace('restored_' + suffix + ', []', 'restored_' + suffix + ', prefix_' + suffix + '.selected_taxa', 1)
            lines.append(call)
            resumes += 1
    lines += ['}', '']
    (ROOT / 'selection_workflow_audit_test.mbt').write_text('\n'.join(lines), encoding='utf-8')
    real = rows['real-1']
    main = ['///|', '// Synthetic testing community on the existing CC0 42-taxon tree.', 'fn main {',
            '  let tree = @phylo.PhyloTree::from_newick(' + json.dumps(real['newick']) + ', rooted=true).unwrap()',
            '  let baseline = ' + strings(real['baseline']), '  let candidates = ' + strings(real['candidates']),
            '  let prefix = tree.faith_pd_greedy(baseline, candidates, 1U).unwrap()',
            '  let restored = @phylo.PhyloTree::from_newick(tree.to_newick()).unwrap()',
            '  let resumed = restored.faith_pd_greedy(prefix.selected_taxa, candidates, 2U).unwrap()',
            '  let full = restored.faith_pd_greedy(baseline, candidates, 3U).unwrap()',
            '  let added = prefix.added_taxa.copy()', '  added.append(resumed.added_taxa)',
            '  println(prefix.to_json().stringify())', '  println(resumed.to_json().stringify())',
            '  println(full.to_json().stringify())',
            '  println(restored.faith_pd(resumed.selected_taxa).unwrap().to_json().stringify())',
            '  println(restored.faith_pd_gain(baseline, added).unwrap().to_json().stringify())',
            '  println(tree.nodes().to_json().stringify())', '  println(restored.nodes().to_json().stringify())', '}', '']
    target = ROOT / 'cmd/selection_resume/main.mbt'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('\n'.join(main), encoding='utf-8')
    full_facts = next(x for x in json.loads(facts.read_text(encoding='utf-8'))['fixtures'] if x['name'] == 'real-all')
    selected = set(real['baseline'] + real['order'])
    absolute = sum((Fraction.from_float(e['length']) for e in full_facts['edges'] if selected.intersection(e['descendant_taxa'])), Fraction(0))
    receipt = {'biopython': Bio.__version__, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
               'source_facts_sha256': hashlib.sha256(facts.read_bytes()).hexdigest(), 'seed_cases': names,
               'rotation_cases': len(seeds), 'roundtrip_cases': len(seeds), 'prefix_resume_cases': resumes,
               'rotated_branch_facts_checked': True, 'consumer': real, 'consumer_absolute_bits': bits(absolute),
               'old_generators_replayed': False, 'runtime_API_changes': False}
    if args.receipt:
        args.receipt.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in receipt.items() if k not in ('consumer',)}, ensure_ascii=False))

if __name__ == '__main__':
    main()
