"""Consume complete Fitch reviews from a separate public MoonBit module.

The expected node tables/changes are literal before-edit facts. A separate
exhaustive labelling search confirms the minimum cost without Fitch recurrence.
Only Git-tracked current sources are copied; stage new local source files first.
No old scientific/native suite or external reference package is needed here.
"""
from pathlib import Path
import argparse
import hashlib
import itertools
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exhaustive(case):
    alphabet = sorted({state for state in case['traits'].values() if state != '?'})
    if not alphabet:
        return {'minimum': 0, 'enumerated': 0}
    fixed = {n['role']: case['traits'][n['label']] for n in case['nodes']
             if not n['children'] and case['traits'][n['label']] != '?'}
    free = [n['role'] for n in case['nodes'] if n['role'] not in fixed]
    minimum, count = len(case['nodes']), 0
    for states in itertools.product(alphabet, repeat=len(free)):
        chosen = {**fixed, **dict(zip(free, states))}
        cost = sum(chosen[n['role']] != chosen[n['parent']] for n in case['nodes'] if n['parent'])
        minimum = min(minimum, cost)
        count += 1
    return {'minimum': minimum, 'enumerated': count}


def validate(value, case):
    assert value['ok'] is True and value['source_unchanged'] is True
    assert value['rooting'] == 'Rooted' and value['traits'] == case['traits']
    original = value['original_nodes']
    nodes = {node['id']: node for node in original}
    hand = {n['role']: n for n in case['nodes']}
    assert len(nodes) == len(original) == len(hand)
    roots = [role for role, n in hand.items() if n['parent'] is None]
    assert len(roots) == 1
    roles = {roots[0]: value['root_id']}
    pending = roots.copy()
    while pending:
        role = pending.pop()
        n, expected = nodes[roles[role]], hand[role]
        assert n['label'] == expected['label'] and n.get('length') == expected['length']
        assert n['comments'] == expected['comments'] and len(n['children']) == len(expected['children'])
        for child, child_id in zip(expected['children'], n['children']):
            assert child not in roles
            roles[child] = child_id
            pending.append(child)
    assert set(roles) == set(hand) and set(nodes) == set(range(len(nodes)))
    for role, expected in hand.items():
        assert nodes[roles[role]].get('parent') == (roles[expected['parent']] if expected['parent'] else None)
    by_id = {node_id: hand[role] for role, node_id in roles.items()}
    candidates = [by_id[i]['candidates'] for i in range(len(nodes))]
    assignment = [[by_id[i]['assignment']] if by_id[i]['assignment'] is not None else None for i in range(len(nodes))]
    changed = [[roles[hand[child]['parent']], roles[child]] for child in case['changedChildRoles']]
    expected_report = {'score': case['score'], 'candidates': candidates, 'assignment': assignment,
                       'changed_edges': changed, 'missing_taxa': case['missingTaxa']}
    assert value['parsimony'] == expected_report
    annotations = []
    for node in original:
        expected = by_id[node['id']]
        observed = case['traits'][expected['label']] if not expected['children'] else None
        annotations.append({'id': node['id'], 'observed': observed, 'candidate_states': expected['candidates'],
                            'reconstructed_state': expected['assignment']})
    assert value['node_annotations'] == annotations
    changes = []
    for child_role in case['changedChildRoles']:
        child = hand[child_role]
        parent = hand[child['parent']]
        changes.append({'parent_id': roles[parent['role']], 'child_id': roles[child_role],
                        'from_state': parent['assignment'], 'to_state': child['assignment']})
    assert value['changes'] == changes and len(changes) == case['score']
    search = exhaustive(case)
    assert search['minimum'] == case['score']
    chosen = {n['role']: n['assignment'] for n in case['nodes']}
    assert sum(chosen[n['role']] != chosen[n['parent']] for n in case['nodes'] if n['parent']) == search['minimum']
    return {'score': case['score'], 'expectedRawReport': expected_report, 'expectedNodeAnnotations': annotations,
            'expectedChanges': changes, 'independentExhaustive': search}


def validate_error(value, case):
    assert value['ok'] is False and value['error'] == case['error'], (case['name'], value)
    if 'detailPrefix' in case:
        assert value['detail'].startswith(case['detailPrefix'])
    if 'taxon' in case:
        assert value['taxon'] == case['taxon']
    if 'missingTaxa' in case:
        assert value['missing_taxa'] == case['missingTaxa'] and value['extra_taxa'] == case['extraTaxa']
    if 'nodeLabel' in case:
        nodes = {node['id']: node for node in value['original_nodes']}
        actual = nodes[value['node_id']]
        assert actual['label'] == case['nodeLabel'] and len(actual['children']) == case['childCount']
        assert value['child_count'] == case['childCount']
    if case['error'] in ['rooted_tree_required', 'trait_mismatch', 'unsupported_trait', 'unary_not_supported', 'polytomy_not_supported']:
        assert value['source_unchanged'] is True and value['original_nodes'] and value['detail']
        nodes = {node['id']: node for node in value['original_nodes']}
        assert 'parent' not in nodes[value['root_id']]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--moon', default='moon')
    parser.add_argument('--moonrun', required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    workspace = output / 'workspace'
    product = workspace / 'product'
    receiver = workspace / 'receiver'
    product.mkdir(parents=True)
    env = os.environ.copy()
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    genv = {key: value for key, value in env.items() if not key.startswith('GIT_')}
    genv.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    names = subprocess.check_output(['git', '-c', 'core.autocrlf=false', 'ls-files', '-z'], cwd=ROOT, env=genv).decode().split('\0')
    names = sorted(name for name in names if name)
    assert 'examples/fitch_character_review/main.mbt' in names and 'verification/fitch_character_cases.json' in names, 'Stage new local sources first'
    copied = []
    for name in names:
        dest = product / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
        assert sha(dest) == sha(ROOT / name)
        copied.append({'path': name, 'sha256': sha(dest)})
    shutil.copytree(product / 'examples/fitch_character_review', receiver)
    manifest = workspace / 'moon.work'
    manifest.write_text('members = ["./product", "./receiver"]\n', encoding='utf-8', newline='\n')
    env['MOON_WORK'] = str(manifest)
    build = workspace / 'build'
    commands = [{'label': 'own-workspace-manifest', 'path': str(manifest), 'sha256': sha(manifest), 'MOON_WORK': str(manifest)}]

    def moon(label, arguments):
        q = subprocess.run([args.moon, *arguments], cwd=workspace, env=env, capture_output=True)
        (output / (label + '.stdout.txt')).write_bytes(q.stdout)
        (output / (label + '.stderr.txt')).write_bytes(q.stderr)
        commands.append({'label': label, 'args': arguments, 'exit_code': q.returncode})
        assert q.returncode == 0, (label, q.stderr.decode('utf-8', errors='replace'))

    fixture = ROOT / 'verification/fitch_character_cases.json'
    fixture_hash = sha(fixture)
    data = json.loads(fixture.read_text(encoding='utf-8'))
    inputs = output / 'inputs'
    inputs.mkdir()
    immutable = {}

    def saved(name, extension, text):
        path = inputs / (name + extension)
        path.write_bytes(text.encode('utf-8'))
        immutable[str(path)] = sha(path)
        return path

    requests = []
    for case in data['cases'] + data['errors']:
        tree = saved(case['name'], '.newick', case['newick']) if case['newick'] is not None else None
        traits = None if case.get('omitTraits') else saved(case['name'], '.traits.json', case.get('traitsJSON', json.dumps(case['traits'], ensure_ascii=True)))
        requests.append((case, tree, traits))
    runs, compiled, checks, errors = [], [], [], []
    for target in ['js', 'wasm-gc']:
        moon('check-' + target, ['-C', 'receiver', '--target-dir', str(build), 'check', '--target', target, '--deny-warn', '--frozen'])
        moon('build-' + target, ['-C', 'receiver', '--target-dir', str(build), 'build', '.', '--target', target, '--deny-warn', '--frozen'])
        extension = 'js' if target == 'js' else 'wasm'
        relative_main = 'example/fitch-character-review/fitch-character-review.' + extension
        artifact = build / target / 'debug/build' / relative_main
        runner = shutil.which('node') if target == 'js' else args.moonrun
        for relative in [relative_main, 'liubin-dev/phylo/phylo.mi', 'liubin-dev/phylo/phylo.core']:
            path = build / target / 'debug/build' / relative
            assert path.is_file(), path
            compiled.append({'target': target, 'artifact': relative, 'path': str(path), 'sha256': sha(path), 'bytes': path.stat().st_size})
        for case, tree, traits in requests:
            process_env = env.copy()
            process_env.pop('PHYLO_FITCH_TREE', None)
            process_env.pop('PHYLO_FITCH_TRAITS', None)
            if tree is not None:
                process_env['PHYLO_FITCH_TREE'] = tree.read_text(encoding='utf-8')
            if traits is not None:
                process_env['PHYLO_FITCH_TRAITS'] = traits.read_text(encoding='utf-8')
            q = subprocess.run([runner, str(artifact)], cwd=workspace, env=process_env, capture_output=True, timeout=30)
            stdout = output / (target + '-' + case['name'] + '.stdout.json')
            stdout.write_bytes(q.stdout)
            (output / (target + '-' + case['name'] + '.stderr.txt')).write_bytes(q.stderr)
            assert q.returncode == 0 and not q.stderr, (case['name'], q.stderr)
            value = json.loads(q.stdout)
            runs.append({'target': target, 'case': case['name'], 'artifactSHA256': sha(artifact), 'stdoutSHA256': sha(stdout), 'ok': value['ok']})
            if 'error' in case:
                validate_error(value, case)
                errors.append({'target': target, 'case': case['name'], 'expectedError': case['error']})
            else:
                checks.append(dict(target=target, case=case['name'], **validate(value, case)))
    assert sha(fixture) == fixture_hash and all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = {'status': 'passed', 'publicModule': 'example/fitch-character-review', 'libraryDependency': 'liubin-dev/phylo@0.1.0 via local workspace',
              'privateImports': False, 'oracle': data['oracle'], 'fixtureSHA256': fixture_hash, 'copiedSource': copied, 'commands': commands,
              'compiled': compiled, 'runs': runs, 'count': len(runs), 'independentChecks': checks, 'independentErrors': errors, 'inputSHA256': immutable,
              'adoptionBoundary': 'Self-authored actual configurable receiving review, not third-party adoption, alignment/new model or deployed viewer'}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({'status': 'passed', 'publicFitchCalls': len(runs), 'completeHandReviews': len(checks), 'explicitErrors': len(errors)}))


if __name__ == '__main__':
    main()
