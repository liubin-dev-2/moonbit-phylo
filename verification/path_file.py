"""Real original-Newick file handoff with an authored graph, not an NJ oracle.

Reuse only pure BFS/Fraction checking helpers, never their previous scenarios or
generator mains. File/env equality is a compatibility check beside complete
independent source graph, ordered path, comments, rooting and stem assertions.
"""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess
from patristic_path import validate, bits, reject_constant

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_original(value, case, start, finish):
    checked = validate(value, case, start, finish)
    nodes = {node['id']: node for node in value['nodes']}
    roots = [node for node in nodes.values() if 'parent' not in node]
    assert len(roots) == 1 and roots[0]['label'] == 'R'
    assert bits(roots[0]['length']) == bits(case['root_stem'])
    children = {}
    parents = {}
    for a, b, _ in case['edges']:
        children.setdefault(a, []).append(b)
        parents[b] = a
    for node in nodes.values():
        assert [nodes[i]['label'] for i in node['children']] == children.get(node['label'], [])
        if 'parent' in node:
            assert nodes[node['parent']]['label'] == parents[node['label']]
        assert node['comments'] == case['node_comments'].get(node['label'], [])
    assert value['tree_newick'].endswith(';' + ''.join('[' + c + ']' for c in case['tree_comments']))
    return checked


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--artifact-dir', required=True)
    parser.add_argument('--moonrun', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--baseline-artifact-dir')
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    inputs = output / '原始 trees with spaces'
    inputs.mkdir(exist_ok=True)
    fixture = ROOT / 'verification/path_file_case.json'
    fixture_hash = sha(fixture)
    case = json.loads(fixture.read_text(encoding='utf-8'))
    small = {'name': 'small', 'rooting': 'rooted', 'newick': "[&R]((('Café':0)U:2,'Café':3)X:4,'O''Brien_😀':5)R:99;[small]",
             'edges': [['R', 'X', 4], ['X', 'U', 2], ['U', 'Café', 0], ['X', 'Café', 3], ['R', "O'Brien_😀", 5]],
             'queries': [['Café', "O'Brien_😀"], ["O'Brien_😀", 'Café'], ['Café', 'Café']],
             'node_comments': {}, 'tree_comments': ['small'], 'root_stem': 99}
    artifacts = {target: Path(args.artifact_dir).resolve() / target / 'debug/build/cmd/patristic_path' /
                 ('patristic_path.js' if target == 'js' else 'patristic_path.wasm') for target in ['js', 'wasm-gc']}
    runners = {'js': shutil.which('node'), 'wasm-gc': args.moonrun}
    immutable = {}
    runs = []
    checked = []

    def write(name, raw):
        path = inputs / name
        path.write_bytes(raw)
        immutable[str(path)] = sha(path)
        return path

    def call(name, target='js', path=None, text=None, start='A', finish='B', artifact=None):
        env = os.environ.copy()
        for key in ['PHYLO_PATH_TREE_FILE', 'PHYLO_PATH_TREE', 'PHYLO_PATH_FROM', 'PHYLO_PATH_TO']:
            env.pop(key, None)
        for key, val in [('PHYLO_PATH_TREE_FILE', str(path) if path is not None else None),
                         ('PHYLO_PATH_TREE', text), ('PHYLO_PATH_FROM', start), ('PHYLO_PATH_TO', finish)]:
            if val is not None:
                env[key] = val
        executable = artifact or artifacts[target]
        assert executable.is_file() and runners[target]
        run = subprocess.run([runners[target], str(executable)], cwd=ROOT, env=env, capture_output=True, timeout=60)
        stem = output / name
        stem.with_suffix('.stdout.json').write_bytes(run.stdout)
        stem.with_suffix('.stderr.txt').write_bytes(run.stderr)
        assert run.returncode == 0 and not run.stderr, (name, run.returncode, run.stderr)
        value = json.loads(run.stdout, parse_constant=reject_constant)
        runs.append({'case': name, 'target': target, 'artifact_sha256': sha(executable),
                     'path': str(path) if path is not None else None, 'tree_payload_in_environment': text is not None,
                     'stdout_sha256': hashlib.sha256(run.stdout).hexdigest(), 'exit_code': run.returncode, 'ok': True})
        return value

    for source_case in [case, small]:
        path = write(source_case['name'] + ' 中文 tree.newick', source_case['newick'].encode('utf-8'))
        for i, (start, finish) in enumerate(source_case['queries']):
            name = source_case['name'] + '-' + str(i)
            value = call(name + '-file', path=path, start=start, finish=finish)
            checked.append(check_original(value, source_case, start, finish))
            for target in ['js', 'wasm-gc']:
                assert call(name + '-env-' + target, target, text=source_case['newick'], start=start, finish=finish) == value
                if args.baseline_artifact_dir:
                    baseline = Path(args.baseline_artifact_dir).resolve() / target / 'debug/build/cmd/patristic_path' / artifacts[target].name
                    assert call(name + '-base-' + target, target, text=source_case['newick'], start=start, finish=finish, artifact=baseline) == value
            if i == 0:
                relative = os.path.relpath(path, ROOT)
                assert call(name + '-relative', path=relative, start=start, finish=finish) == value
    large = inputs / (case['name'] + ' 中文 tree.newick')
    assert large.stat().st_size == 42163 and len(case['taxa']) == 64 and len(case['edges']) == 66
    failures = [
        ('invalid-utf8', b"('A\xff':1,B:2)R;", 'invalid_utf8'),
        ('truncated-utf8', b"('A\xe4\xb8", 'invalid_utf8'),
        ('bom', b'\xef\xbb\xbf[&U](A:1,B:2)R;', 'tree_error'),
        ('bad-tree', b'(A:1,B:2', 'tree_error'),
        ('multiple-trees', b'(A:1,B:2)R;(A:1,B:2)S;', 'tree_error'),
        ('missing-off-path', b'[&R]((A:1,B:2)X:3,C)R;', 'missing_length'),
    ]
    for name, raw, code in failures:
        path = write(name + '.newick', raw)
        value = call(name + '-file', path=path)
        assert value['ok'] is False and value['error'] == code and 'path' not in value, (name, value)
        if code != 'invalid_utf8':
            for target in ['js', 'wasm-gc']:
                assert call(name + '-env-' + target, target, text=raw.decode('utf-8')) == value
    first = case['queries'][0][0]
    for name, start, taxon in [('unknown', 'not-present', 'not-present'), ('internal', 'X', 'X')]:
        value = call(name, path=large, start=start, finish=first)
        assert value['ok'] is False and value['error'] == 'unknown_taxon' and value['taxon'] == taxon
    for name, path in [('missing-file', inputs / 'does-not-exist.newick'), ('directory', inputs), ('literal-wildcard', str(inputs / '*.newick'))]:
        value = call(name, path=path)
        assert value['ok'] is False and value['error'] == 'file_read_error'
        assert value['code'] in (['EISDIR', 'EPERM', 'EACCES'] if name == 'directory' else ['ENOENT'])
    assert not (inputs / 'does-not-exist.newick').exists()
    for target in ['js', 'wasm-gc']:
        assert call('empty-path-' + target, target, path='') == {'ok': False, 'error': 'empty_tree_file'}
        assert call('conflict-' + target, target, path=large, text='') == {'ok': False, 'error': 'input_source_conflict'}
        assert call('empty-conflict-' + target, target, path='', text='') == {'ok': False, 'error': 'input_source_conflict'}
        assert call('missing-tree-' + target, target) == {'ok': False, 'error': 'missing_tree'}
        assert call('legacy-missing-from-' + target, target, text='(A:1,B:2)R;', start=None) == {'ok': False, 'error': 'missing_from'}
        assert call('legacy-missing-to-' + target, target, text='(A:1,B:2)R;', finish=None) == {'ok': False, 'error': 'missing_to'}
    assert call('wasm-file', 'wasm-gc', path=large) == {'ok': False, 'error': 'unsupported_file_host'}
    assert call('file-missing-from', path=large, start=None) == {'ok': False, 'error': 'missing_from'}
    assert call('file-missing-to', path=large, finish=None) == {'ok': False, 'error': 'missing_to'}
    assert call('read-before-endpoint', path=inputs / 'absent.newick', start=None)['error'] == 'file_read_error'
    assert call('decode-before-endpoint', path=inputs / 'invalid-utf8.newick', start=None)['error'] == 'invalid_utf8'
    assert call('parse-after-endpoint', path=inputs / 'bad-tree.newick', start=None)['error'] == 'missing_from'
    assert sha(fixture) == fixture_hash
    assert all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = {'status': 'passed', 'fileHost': 'Node/CommonJS JS only; Wasm-GC file mode explicitly rejected',
              'fixture_sha256': fixture_hash, 'original_input_sha256': sha(large), 'original_input_bytes': large.stat().st_size,
              'independent_results': checked, 'full_graph_labels': 64, 'full_graph_edges': 66,
              'completeCommentsRootingStemChildrenChecked': True, 'immutable_inputs_sha256': immutable,
              'runs': runs, 'count': len(runs), 'scientificFixturesRegenerated': False}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'passed', 'consumer_calls': len(runs), 'independent_file_queries': len(checked),
                      'original_bytes': large.stat().st_size, 'full_graph_edges': 66}))


if __name__ == '__main__':
    main()
