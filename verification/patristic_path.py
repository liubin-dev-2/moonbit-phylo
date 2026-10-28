"""Actual public path consumers against authored edge graphs and Fraction sums.

No previous product result supplies expected routes or distances. BFS on each
saved undirected graph is independent of the library's parent/LCA path walk.
Every executable call records its identity and captures its complete output.
"""
from pathlib import Path
from collections import deque
from fractions import Fraction
import argparse, hashlib, json, math, os, shutil, struct, subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bits(value):
    return struct.pack('>d', float(value)).hex()


def graph(case):
    adj = {}
    for a, b, weight in case['edges']:
        adj.setdefault(a, []).append((b, float(weight)))
        adj.setdefault(b, []).append((a, float(weight)))
    for a, b in case['queries']:
        adj.setdefault(a, [])
        adj.setdefault(b, [])
    return adj


def expected_route(adj, start, finish):
    queue = deque([(start, [start], [])])
    seen = {start}
    while queue:
        current, route, weights = queue.popleft()
        if current == finish:
            exact = sum((Fraction(x) for x in weights), Fraction())
            return route, weights, float(exact)
        for other, weight in adj[current]:
            if other not in seen:
                seen.add(other)
                queue.append((other, route + [other], weights + [weight]))
    raise AssertionError('Authored graph has no requested route')


def validate(payload, case, start, finish):
    assert payload['ok'] is True
    # Rooting derives its existing public ToJson representation.
    assert payload['rooting'] == case['rooting'].capitalize()
    nodes = {node['id']: node for node in payload['nodes']}
    labels = {index: node['label'] for index, node in nodes.items()}
    assert len(labels) == len(set(labels.values()))
    expected_edges = {tuple(sorted((a, b))): bits(weight) for a, b, weight in case['edges']}
    actual_edges = {tuple(sorted((labels[node['id']], labels[node['parent']]))): bits(node['length'])
                    for node in nodes.values() if 'parent' in node}
    assert actual_edges == expected_edges
    assert set(labels.values()) == set(graph(case))
    path = payload['path']
    assert path['from_taxon'] == start and path['to_taxon'] == finish
    route, weights, distance = expected_route(graph(case), start, finish)
    assert [labels[index] for index in path['node_ids']] == route
    assert len(path['edge_ids']) + 1 == len(path['node_ids'])
    assert len(path['node_ids']) == len(set(path['node_ids']))
    assert len(path['edge_ids']) == len(set(path['edge_ids']))
    assert bits(path['distance']) == bits(distance)
    assert math.isfinite(path['distance'])
    for i, edge in enumerate(path['edge_ids']):
        a, b = path['node_ids'][i:i + 2]
        assert nodes[edge]['parent'] is not None
        assert {edge, nodes[edge]['parent']} == {a, b}
        assert bits(nodes[edge]['length']) == bits(weights[i])
    return {'node_route': route, 'edge_length_bits': [bits(x) for x in weights], 'distance_bits': bits(distance)}


def reject_constant(value):
    raise AssertionError('Nonfinite JSON output: ' + value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--artifact-dir', required=True)
    parser.add_argument('--moonrun', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    fixture = ROOT / 'verification/patristic_path_cases.json'
    fixture_hash = sha(fixture)
    data = json.loads(fixture.read_text(encoding='utf-8'))
    inputs = output / 'inputs'
    inputs.mkdir(exist_ok=True)
    immutable = {}
    for case in data['cases'] + data['errors']:
        path = inputs / (case['name'] + '.newick')
        path.write_bytes(case['newick'].encode('utf-8'))
        immutable[str(path)] = sha(path)
    runs = []
    results = {}
    for target in ['js', 'wasm-gc']:
        artifact = Path(args.artifact_dir).resolve() / target / 'debug/build/cmd/patristic_path' / ('patristic_path.js' if target == 'js' else 'patristic_path.wasm')
        runner = shutil.which('node') if target == 'js' else args.moonrun
        assert artifact.is_file() and runner
        artifact_hash = sha(artifact)

        def call(name, newick=None, start=None, finish=None):
            env = os.environ.copy()
            for key in ['PHYLO_PATH_TREE', 'PHYLO_PATH_FROM', 'PHYLO_PATH_TO']:
                env.pop(key, None)
            for key, value in [('PHYLO_PATH_TREE', newick), ('PHYLO_PATH_FROM', start), ('PHYLO_PATH_TO', finish)]:
                if value is not None:
                    env[key] = value
            run = subprocess.run([runner, str(artifact)], env=env, capture_output=True, timeout=30)
            stem = target + '-' + name
            (output / (stem + '.stdout.json')).write_bytes(run.stdout)
            (output / (stem + '.stderr.txt')).write_bytes(run.stderr)
            assert run.returncode == 0 and not run.stderr, (stem, run.returncode, run.stderr)
            value = json.loads(run.stdout, parse_constant=reject_constant)
            runs.append({'target': target, 'case': name, 'artifact_sha256': artifact_hash, 'ok': True})
            return value

        for case in data['cases']:
            source = inputs / (case['name'] + '.newick')
            for i, (start, finish) in enumerate(case['queries']):
                name = case['name'] + '-' + str(i)
                value = call(name, source.read_text(encoding='utf-8'), start, finish)
                checked = validate(value, case, start, finish)
                results[target + '-' + name] = checked
                if i == 0:
                    # Reparse an actual export, still checked against the saved
                    # graph, not against the previous output's IDs or distance.
                    exported = output / (target + '-' + case['name'] + '.export.newick')
                    exported.write_bytes(value['tree_newick'].encode('utf-8'))
                    immutable[str(exported)] = sha(exported)
                    reloaded = call(name + '-reparse', exported.read_text(encoding='utf-8'), start, finish)
                    assert validate(reloaded, case, start, finish) == checked
        for case in data['errors']:
            value = call(case['name'], (inputs / (case['name'] + '.newick')).read_text(encoding='utf-8'), case['from'], case['to'])
            assert value['ok'] is False and value['error'] == case['error'] and 'path' not in value, (case['name'], value)
            if 'taxon' in case:
                assert value['taxon'] == case['taxon']
        for name, newick, start, finish, error in [
                ('missing-tree', None, None, None, 'missing_tree'),
                ('missing-from', '(A:1,B:1)R;', None, 'B', 'missing_from'),
                ('missing-to', '(A:1,B:1)R;', 'A', None, 'missing_to')]:
            assert call(name, newick, start, finish) == {'ok': False, 'error': error}
        assert sha(artifact) == artifact_hash
    for key, value in results.items():
        if key.startswith('js-'):
            assert value == results['wasm-gc-' + key.removeprefix('js-')]
    assert sha(fixture) == fixture_hash
    assert all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = {'status': 'passed', 'oracle': data['oracle'], 'fixture_sha256': fixture_hash,
              'independent_results': results, 'immutable_inputs_sha256': immutable,
              'runs': runs, 'count': len(runs), 'targets': ['js', 'wasm-gc'],
              'boundary': 'Existing Newick environment transport, typed public path API, actual export/reparse. Node NJ file host unchanged; no new path file/stdin host.'}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'passed', 'consumer_calls': len(runs), 'independent_queries_per_target': len(results) // 2}))


if __name__ == '__main__':
    main()
