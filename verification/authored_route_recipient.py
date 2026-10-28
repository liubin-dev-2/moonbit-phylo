"""Build a separate public module, then verify literal original-ID highlights.

The hand roles/routes are independent data. Each expected role is mapped through
the recipient's original pre-query NodeRecord snapshot, never through a route.
No private product package, fabricated lengths, transform or old generator.
"""
from pathlib import Path
import argparse, hashlib, json, os, shutil, struct, subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bits(value):
    return struct.pack('>d', float(value)).hex()


def validate(value, case, query, index):
    assert value['ok'] is True and value['ownership_verified'] and value['source_unchanged']
    assert value['rooting'] == case['rooting']
    original = value['original_nodes']
    nodes = {node['id']: node for node in original}
    roles = {node['label']: node['id'] for node in original}
    assert len(roles) == len(original) == len(case['nodes'])
    assert set(roles) == {node['role'] for node in case['nodes']}
    comments = {'U': ['u-note'], 'R': ['r-note']} if case['name'] == 'stem' else {}
    for expected in case['nodes']:
        node = nodes[roles[expected['role']]]
        assert [nodes[i]['label'] for i in node['children']] == expected['children']
        assert node.get('parent') == (roles[expected['parent']] if expected['parent'] else None)
        assert node.get('length') == expected.get('length')
        assert node['comments'] == comments.get(expected['role'], [])
    if case['name'] == 'stem':
        assert value['source_newick'].endswith(';[tree-note]')
    route = value['route']
    expected_nodes = [roles[role] for role in query['nodeRoles']]
    expected_edges = [roles[role] for role in query['edgeChildRoles']]
    assert route == {'from_taxon': query['from'], 'to_taxon': query['to'], 'node_ids': expected_nodes,
                     'edge_ids': expected_edges, 'authored_edge_count': query['authored_edge_count']}
    assert route['authored_edge_count'] == len(expected_edges) == len(expected_nodes) - 1
    for i, edge in enumerate(expected_edges):
        assert {edge, nodes[edge]['parent']} == set(expected_nodes[i:i + 2])
    # The public recipient applies the ordered IDs to its original style tables.
    assert len(value['node_styles']) == len(original)
    assert len(value['edge_styles']) == sum('parent' in node for node in original)
    for style in value['node_styles']:
        expected = expected_nodes.index(style['id']) if style['id'] in expected_nodes else None
        assert style['highlighted'] == (expected is not None) and style['route_index'] == expected
    for style in value['edge_styles']:
        assert style['parent_id'] == nodes[style['child_id']]['parent']
        expected = expected_edges.index(style['child_id']) if style['child_id'] in expected_edges else None
        assert style['highlighted'] == (expected is not None) and style['route_index'] == expected
    if case['weighted'] == 'missing':
        assert value['weighted_distance']['ok'] is False and value['weighted_path']['ok'] is False
        assert value['weighted_distance']['detail'].startswith('MissingLength(')
        assert value['weighted_distance'] == value['weighted_path']
    else:
        expected = case['weighted'][index]
        assert value['weighted_distance']['ok'] is True
        assert bits(value['weighted_distance']['distance']) == bits(expected)
        weighted = value['weighted_path']
        assert weighted['node_ids'] == expected_nodes and weighted['edge_ids'] == expected_edges
        assert bits(weighted['distance']) == bits(expected)
    return {'nodeRoles': query['nodeRoles'], 'edgeChildRoles': query['edgeChildRoles'], 'count': len(expected_edges)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--moon', default='moon')
    parser.add_argument('--moonrun', required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=False)
    workspace = output / 'workspace'; product = workspace / 'product'; receiver = workspace / 'receiver'
    product.mkdir(parents=True)
    env = os.environ.copy(); env['PYTHONDONTWRITEBYTECODE'] = '1'
    genv = {k: v for k, v in env.items() if not k.startswith('GIT_')}
    genv.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    def git(*args):
        return subprocess.check_output(['git', '-c', 'core.autocrlf=false', *args], cwd=ROOT, env=genv).decode().split('\0')
    files = sorted(set(git('ls-files', '-z') + git('ls-files', '--others', '--exclude-standard', '-z')) - {''})
    copied = []
    for name in files:
        destination = product / name; destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, destination)
        assert sha(destination) == sha(ROOT / name)
        copied.append({'path': name, 'sha256': sha(destination)})
    shutil.copytree(ROOT / 'examples/authored_route_highlighter', receiver)
    build = workspace / 'build'
    commands = []
    def moon(label, args):
        run = subprocess.run([args_moon, *args], cwd=workspace, env=env, capture_output=True)
        (output / (label + '.stdout.txt')).write_bytes(run.stdout); (output / (label + '.stderr.txt')).write_bytes(run.stderr)
        commands.append({'args': args, 'exit_code': run.returncode})
        assert run.returncode == 0, (label, run.stderr.decode(errors='replace'))
    args_moon = args.moon
    moon('workspace-init', ['work', 'init', './product', './receiver'])
    fixture = ROOT / 'verification/authored_route_cases.json'; fixture_hash = sha(fixture)
    data = json.loads(fixture.read_text(encoding='utf-8'))
    inputs = output / 'inputs'; inputs.mkdir(); immutable = {}
    for case in data['cases'] + data['errors']:
        path = inputs / (case['name'] + '.newick'); path.write_bytes(case.get('newick', case.get('tree')).encode('utf-8')); immutable[str(path)] = sha(path)
    runs = []; compiled = []; checks = []
    for target in ['js', 'wasm-gc']:
        moon('build-' + target, ['-C', 'receiver', '--target-dir', str(build), 'build', '.', '--target', target, '--deny-warn', '--frozen'])
        extension = 'js' if target == 'js' else 'wasm'
        artifact = build / target / 'debug/build/example/authored-route-highlighter' / ('authored-route-highlighter.' + extension)
        assert artifact.is_file(), artifact
        runner = shutil.which('node') if target == 'js' else args.moonrun
        for relative in ['example/authored-route-highlighter/authored-route-highlighter.' + extension, 'liubin-dev/phylo/phylo.mi', 'liubin-dev/phylo/phylo.core']:
            path = build / target / 'debug/build' / relative
            assert path.is_file(), path
            compiled.append({'target': target, 'artifact': relative, 'path': str(path), 'sha256': sha(path), 'bytes': path.stat().st_size})
        def call(name, text, start, finish):
            process_env = env.copy(); process_env.update(PHYLO_ROUTE_TREE=text, PHYLO_ROUTE_FROM=start, PHYLO_ROUTE_TO=finish)
            q = subprocess.run([runner, str(artifact)], env=process_env, capture_output=True, timeout=30)
            stem = output / (target + '-' + name)
            stem.with_suffix('.stdout.json').write_bytes(q.stdout); stem.with_suffix('.stderr.txt').write_bytes(q.stderr)
            assert q.returncode == 0 and not q.stderr, (name, q.stderr)
            value = json.loads(q.stdout)
            runs.append({'target': target, 'case': name, 'artifactSHA256': sha(artifact), 'stdoutSHA256': hashlib.sha256(q.stdout).hexdigest(), 'ok': True})
            return value
        for case in data['cases']:
            text = (inputs / (case['name'] + '.newick')).read_text(encoding='utf-8')
            for i, query in enumerate(case['queries']):
                value = call(case['name'] + '-' + str(i), text, query['from'], query['to'])
                checks.append(dict(target=target, case=case['name'], **validate(value, case, query, i)))
        for case in data['errors']:
            value = call(case['name'], (inputs / (case['name'] + '.newick')).read_text(encoding='utf-8'), case['from'], case['to'])
            assert value['ok'] is False and value['error'] == case['error']
            if 'taxon' in case:
                assert value['taxon'] == case['taxon']
    assert sha(fixture) == fixture_hash and all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = {'status': 'passed', 'publicModule': 'example/authored-route-highlighter', 'libraryDependency': 'liubin-dev/phylo@0.1.0 via local workspace',
              'privateImports': False, 'oracle': data['oracle'], 'fixtureSHA256': fixture_hash, 'copiedSource': copied, 'commands': commands,
              'compiled': compiled, 'runs': runs, 'count': len(runs), 'independentChecks': checks, 'inputSHA256': immutable,
              'adoptionBoundary': 'Runnable public-package highlighting example only; no deployed viewer, signature, adoption or performance evidence'}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'passed', 'publicHighlighterCalls': len(runs), 'independentRoutes': len(checks)}))


if __name__ == '__main__':
    main()
