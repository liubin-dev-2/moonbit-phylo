"""Marginal PD truth from sealed independent descendant-edge facts, not runtime.

Reads only the round08 diversity golden input, never MoonBit implementation
source. No external package, network, old-generator replay or data conversion.
"""
from fractions import Fraction
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]


def strings(values):
    return '[' + ', '.join(json.dumps(x, ensure_ascii=False) for x in values) + ']'


def bits(value):
    return struct.pack('>d', value).hex()


def reference(name, full, baseline, additions):
    old, new = set(baseline), set(additions)
    edges = [edge for edge in full['edges'] if new.intersection(edge['descendant_taxa'])
             and not old.intersection(edge['descendant_taxa'])]
    total = sum((Fraction.from_float(edge['length']) for edge in edges), Fraction(0))
    return {'name': name, 'newick': full['newick'], 'baseline': baseline, 'additions': additions,
            'edges': edges, 'exact_gain': str(total), 'gain_bits': bits(float(total))}


def main():
    source = ROOT / 'testdata/diversity-golden.json'
    independent = json.loads(source.read_text(encoding='utf-8'))
    rows = {x['name']: x for x in independent['fixtures']}
    cases = []
    sets = [[label for bit, label in enumerate('ABCD') if mask & (1 << bit)] for mask in range(16)]
    full = rows['small-0-subset-15']
    for i, baseline in enumerate(sets):
        for j, additions in enumerate(sets):
            cases.append(reference(f'all-pairs-{i}-{j}', full, baseline, additions))
    targeted = [([], ['A']), (['A'], ['A', 'B']), (['A', 'B'], ['C', 'D']),
                (['A', 'C'], ['B', 'D']), (list('ABCD'), list('ABCD'))]
    for topology in (1, 2):
        for index, (baseline, additions) in enumerate(targeted):
            cases.append(reference(f'topology-{topology}-{index}', rows[f'small-{topology}-subset-15'], baseline, additions))
    real = rows['real-all']
    taxa = real['present']
    pairs = [([], taxa[:6]), (taxa[:6], taxa[6:12]), (taxa[::4], taxa[:6]),
             (taxa, taxa[:6]), (taxa[:6], taxa)]
    for index, (baseline, additions) in enumerate(pairs):
        cases.append(reference(f'real-{index}', real, baseline, additions))
    output = {'reference': {'source': 'testdata/diversity-golden.json',
                           'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                           'source_method': independent['reference'],
                           'method': 'edge descendant intersection with additions and no intersection with baseline; Fraction.from_float sum'},
              'fixtures': cases}
    (ROOT / 'testdata/diversity-gain-golden.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    lines = ['// Generated from independent round08 descendant-edge facts.', '///|',
             'test "PD gain independent 271 edge-set and Fraction cases" {',
             '  let cases : Array[(String, Array[String], Array[String], UInt64, Array[(Array[String], Double)])] = [']
    for row in cases:
        edges = '[' + ', '.join('(' + strings(e['descendant_taxa']) + ', 0x' + bits(e['length']) + 'UL.reinterpret_as_double())' for e in row['edges']) + ']'
        lines.append('    (' + json.dumps(row['newick'], ensure_ascii=False) + ', ' + strings(row['baseline']) + ', ' + strings(row['additions']) + ', 0x' + row['gain_bits'] + 'UL, ' + edges + '),')
    lines += ['  ]', '  for (text, baseline, additions, expected, edges) in cases {',
              '    check_pd_gain(read(text), baseline, additions, expected, edges)', '  }', '}', '']
    (ROOT / 'diversity_gain_oracle_test.mbt').write_text('\n'.join(lines), encoding='utf-8')
    print(json.dumps({'independent_cases': len(cases), 'all_subset_pairs': 256,
                      'unary_and_polytomy_cases': 10, 'real_tree_cases': 5,
                      'old_fixtures_regenerated': False, 'new_external_dependencies': 0}))


if __name__ == '__main__':
    main()
