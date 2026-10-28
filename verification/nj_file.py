"""Exercise the actual Node file host, with an independent 128-tip graph oracle.

The saved fixture names every weighted edge of a binary caterpillar. Traversal
and edge cuts produce expectations; neither NJ nor product output generates
them. This also checks the existing environment entry and the explicit Wasm-GC
file-host rejection. Python stdlib only; inputs are hashed before/after reads.
"""
from pathlib import Path
import argparse, hashlib, json, math, os, shutil, struct, subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bits(value):
    return struct.pack('>d', float(value)).hex()


def graph(edges):
    result = {}
    for a, b, weight in edges:
        result.setdefault(a, []).append((b, weight))
        result.setdefault(b, []).append((a, weight))
    return result


def walk(adj, start, blocked=None):
    distances = {start: 0}
    todo = [(start, blocked)]
    while todo:
        node, parent = todo.pop()
        for other, weight in adj[node]:
            if other == parent:
                continue
            assert other not in distances, 'Oracle/output must be a tree'
            distances[other] = distances[node] + weight
            todo.append((other, node))
    return distances


def cut_key(side, taxa):
    other = set(taxa) - set(side)
    return min((tuple(sorted(side)), tuple(sorted(other))), key=lambda x: (len(x), x))


def branches(adj, edges, taxa):
    result = {}
    for a, b, weight in edges:
        assert math.isfinite(weight) and weight >= 0
        key = cut_key(set(walk(adj, a, b)) & set(taxa), taxa)
        assert key not in result, 'Unexpected degree-two/duplicate edge split'
        result[key] = bits(weight)
    return result


def check_large(payload, case):
    taxa = case['taxa']
    adj = graph(case['edges'])
    expected = [[walk(adj, a)[b] for b in taxa] for a in taxa]
    assert case['matrix'] == {'taxa': taxa, 'values': expected}
    assert payload['ok'] is True and payload['schema'] == 'phylo/nj-matrix/v1'
    assert payload['rooting'] == 'unrooted' and payload['newick'].startswith('[&U]')
    assert payload['input'] == case['matrix'] and payload['fitted'] == case['matrix']
    assert payload['residuals'] == [[0] * 128 for _ in taxa]
    assert payload['max_abs_residual'] == payload['rms_residual'] == 0
    nodes = {node['id']: node for node in payload['nodes']}
    leaves = {node['id']: node['label'] for node in nodes.values() if not node['children']}
    assert sorted(leaves.values()) == taxa and len(leaves) == 128
    actual_edges = [(node['parent'], node['id'], node['length'])
                    for node in nodes.values() if 'parent' in node]
    actual_adj = graph(actual_edges)
    actual_branches = branches(actual_adj, actual_edges, leaves)
    actual_branches = {cut_key([leaves[i] for i in side], taxa): length
                       for side, length in actual_branches.items()}
    expected_branches = branches(adj, case['edges'], taxa)
    assert len(actual_edges) == len(expected_branches) == 253
    assert actual_branches == expected_branches
    by_label = {label: index for index, label in leaves.items()}
    for i, a in enumerate(taxa):
        distances = walk(actual_adj, by_label[a])
        assert [bits(distances[by_label[b]]) for b in taxa] == [bits(x) for x in expected[i]]
    return {'taxa': 128, 'branches_exact_bits': 253, 'internal_splits': 125,
            'ordered_paths_exact_bits': 128 * 128, 'input_labels_unchanged': True}


def reject_constant(value):
    raise AssertionError('Nonfinite JSON output: ' + value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--artifact-dir', required=True)
    parser.add_argument('--moonrun', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--baseline-artifact-dir')
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    inputs = output / '输入 files'
    inputs.mkdir(exist_ok=True)
    artifacts = {target: Path(args.artifact_dir).resolve() / target / 'debug/build/cmd/nj_matrix' /
                 ('nj_matrix.js' if target == 'js' else 'nj_matrix.wasm') for target in ['js', 'wasm-gc']}
    runners = {'js': shutil.which('node'), 'wasm-gc': args.moonrun}
    runs = []
    file_hashes = {}

    def write(name, data):
        path = inputs / name
        path.write_bytes(data)
        file_hashes[str(path)] = sha(path)
        return path

    def call(name, target='js', path=None, text=None, reference=None, artifact=None):
        env = os.environ.copy()
        for key in ['PHYLO_NJ_MATRIX_FILE', 'PHYLO_NJ_MATRIX', 'PHYLO_NJ_REFERENCE']:
            env.pop(key, None)
        if path is not None:
            env['PHYLO_NJ_MATRIX_FILE'] = str(path)
        if text is not None:
            env['PHYLO_NJ_MATRIX'] = text
        if reference is not None:
            env['PHYLO_NJ_REFERENCE'] = reference
        executable = artifact or artifacts[target]
        assert executable.is_file() and runners[target]
        run = subprocess.run([runners[target], str(executable)], cwd=ROOT, env=env,
                             capture_output=True, timeout=60)
        (output / (name + '.stdout.json')).write_bytes(run.stdout)
        (output / (name + '.stderr.txt')).write_bytes(run.stderr)
        assert run.returncode == 0 and not run.stderr, (name, run.returncode, run.stderr)
        value = json.loads(run.stdout, parse_constant=reject_constant)
        runs.append({'case': name, 'target': target, 'artifact_sha256': sha(executable),
                     'file_path': str(path) if path is not None else None,
                     'matrix_payload_in_environment': text is not None, 'ok': True})
        return value

    fixture = ROOT / 'verification/nj_file_case.json'
    case = json.loads(fixture.read_text(encoding='utf-8'))
    large = write('128 taxa 中文.json', (json.dumps(case['matrix'], ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8'))
    assert large.stat().st_size > 32767
    checked = check_large(call('large-128-file', path=large), case)
    small = {'taxa': ['D', 'B', 'A', 'C'], 'values': [[0, 11, 10, 7], [11, 0, 3, 10], [10, 3, 0, 9], [7, 10, 9, 0]]}
    identity = {'taxa': [' Café ', 'Café', "quote'😀"], 'values': [[0, 3, 4], [3, 0, 5], [4, 5, 0]]}
    for name, matrix, ref in [('small', small, '[&U]((A:1,B:2):5,C:3,D:4);'), ('identity', identity, None)]:
        text = json.dumps(matrix, ensure_ascii=False, separators=(',', ':'))
        path = write(name + '.json', text.encode('utf-8'))
        file_value = call(name + '-file', path=path, reference=ref)
        assert file_value['ok'] is True
        assert file_value['input']['taxa'] == sorted(matrix['taxa'])
        if ref:
            assert file_value['comparison']['distance'] == 0 and file_value['max_abs_residual'] == 0
        for target in ['js', 'wasm-gc']:
            assert call(name + '-env-' + target, target, text=text, reference=ref) == file_value
            if args.baseline_artifact_dir:
                baseline = Path(args.baseline_artifact_dir).resolve() / target / 'debug/build/cmd/nj_matrix' / artifacts[target].name
                assert call(name + '-baseline-' + target, target, text=text, reference=ref, artifact=baseline) == file_value
        assert call(name + '-bom-file', path=write(name + '-bom.json', b'\xef\xbb\xbf' + text.encode('utf-8')), reference=ref) == file_value

    errors = [
        ('invalid-leading-utf8', b'\xff', 'invalid_utf8', None),
        ('invalid-interior-utf8', b'{"taxa":["A\xff"],"values":[]}', 'invalid_utf8', None),
        ('truncated-utf8', b'\xe4\xb8', 'invalid_utf8', None),
        ('surrogate-utf8', b'\xed\xa0\x80', 'invalid_utf8', None),
        ('empty-json', b'', 'invalid_json', None),
        ('bad-json', b'{', 'invalid_json', None),
        ('double-bom', b'\xef\xbb\xbf\xef\xbb\xbf{}', 'invalid_json', None),
        ('top-level-type', b'[]', 'invalid_field', 'matrix'),
        ('taxa-type', b'{"taxa":"A","values":[]}', 'invalid_field', 'taxa'),
        ('number-type', b'{"taxa":["A","B"],"values":[[0,"1"],[1,0]]}', 'invalid_field', 'values[0][1]'),
        ('asymmetric', b'{"taxa":["A","B"],"values":[[0,1],[2,0]]}', 'asymmetric', None),
    ]
    for name, data, error, field in errors:
        path = write(name + '.json', data)
        value = call(name, path=path)
        assert value['ok'] is False and value['error'] == error, (name, value)
        if field:
            assert value['field'] == field
        if error != 'invalid_utf8':
            assert call(name + '-env-control', text=data.decode('utf-8')) == value
    for name, path, error in [('missing-file', inputs / 'not-created.json', 'file_read_error'),
                              ('directory', inputs, 'file_read_error'), ('empty-path', '', 'empty_matrix_file')]:
        value = call(name, path=path)
        assert value['ok'] is False and value['error'] == error, (name, value)
        if error == 'file_read_error':
            assert value['code'] in (['ENOENT'] if name == 'missing-file' else ['EISDIR', 'EPERM', 'EACCES'])
    assert not (inputs / 'not-created.json').exists()
    assert call('conflict', path=large, text='{}') == {'ok': False, 'error': 'input_source_conflict'}
    assert call('empty-conflict', path='', text='') == {'ok': False, 'error': 'input_source_conflict'}
    assert call('missing-matrix') == {'ok': False, 'error': 'missing_matrix'}
    assert call('wasm-file-unsupported', 'wasm-gc', path=large) == {'ok': False, 'error': 'unsupported_file_host'}
    assert all(sha(Path(path)) == digest for path, digest in file_hashes.items())
    result = {'status': 'passed', 'declared_file_host': 'Node.js JavaScript only; Wasm-GC environment mode retained',
              'fixture_sha256': sha(fixture), 'large_input_bytes': large.stat().st_size, 'independent_checks': checked,
              'inputs_unchanged_sha256': file_hashes, 'runs': runs, 'count': len(runs)}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'passed', 'consumer_calls': len(runs), 'independent_checks': checked}))


if __name__ == '__main__':
    main()
