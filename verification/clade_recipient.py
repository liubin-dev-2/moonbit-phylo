"""Run a separate public module against pre-implementation clade/intruder facts.

Requires a Git checkout with the intended sources tracked (stage new local files
before running). The copied product uses current source bytes, not build caches.
Hand node roles map through original snapshots; no MRCA algorithm generates the
expected clades, extras or annotations. No Python biology package is needed.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(value, case, query):
    assert value['ok'] is True
    assert value['ownership_verified'] is True and value['source_unchanged'] is True
    assert value['rooting'] == 'Rooted'
    original = value['original_nodes']
    nodes = {node['id']: node for node in original}
    hand = {row['role']: row for row in case['nodes']}
    assert len(nodes) == len(original) == len(hand)
    root_roles = [role for role, row in hand.items() if row['parent'] is None]
    assert len(root_roles) == 1
    role_ids = {root_roles[0]: value['root_id']}
    pending = root_roles.copy()
    while pending:
        role = pending.pop()
        source = nodes[role_ids[role]]
        expected = hand[role]
        assert source['label'] == expected['label']
        assert source.get('length') == expected['length']
        assert source['comments'] == expected['comments']
        assert len(source['children']) == len(expected['children'])
        for child_role, child_id in zip(expected['children'], source['children']):
            assert child_role not in role_ids
            role_ids[child_role] = child_id
            pending.append(child_role)
    assert set(role_ids) == set(hand)
    for role, expected in hand.items():
        assert nodes[role_ids[role]].get('parent') == (role_ids[expected['parent']] if expected['parent'] else None)
    expected = query['expected']
    report = {
        'selected_taxa': expected['selectedTaxa'],
        'mrca_id': role_ids[expected['mrcaRole']],
        'clade_taxa': expected['cladeTaxa'],
        'extra_taxa': expected['extraTaxa'],
        'is_monophyletic': expected['isMonophyletic'],
    }
    assert value['report'] == report
    assert value['mrca_node'] == nodes[report['mrca_id']]
    assert value['classification'] == ('complete_clade' if expected['isMonophyletic'] else 'incomplete_clade')
    # Every terminal gets a reason based on the literal expected sets, including
    # outside leaves which must not be mistaken for intruders in the MRCA clade.
    annotations = []
    for node in original:
        if node['children']:
            continue
        taxon = node['label']
        status = 'selected' if taxon in expected['selectedTaxa'] else 'intruder' if taxon in expected['extraTaxa'] else 'outside'
        annotations.append({'id': node['id'], 'taxon': taxon, 'status': status})
    assert value['terminal_annotations'] == annotations
    return {'mrcaRole': expected['mrcaRole'], 'expectedReport': report, 'expectedAnnotations': annotations}


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
    genv = {k: v for k, v in env.items() if not k.startswith('GIT_')}
    genv.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    files = subprocess.check_output(['git', '-c', 'core.autocrlf=false', 'ls-files', '-z'], cwd=ROOT, env=genv).decode().split('\0')
    files = sorted(name for name in files if name)
    assert 'examples/clade_review/main.mbt' in files and 'verification/clade_cases.json' in files, 'Stage new local source files first'
    copied = []
    for name in files:
        dest = product / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
        assert sha(dest) == sha(ROOT / name)
        copied.append({'path': name, 'sha256': sha(dest)})
    shutil.copytree(product / 'examples/clade_review', receiver)
    build = workspace / 'build'
    # Earlier recipients in a CI checkout may have created an ancestor workspace.
    # Own this exact manifest instead of letting `work init` discover that one.
    manifest = workspace / 'moon.work'
    manifest.write_text('members = [\n  "./product",\n  "./receiver",\n]\n', encoding='utf-8', newline='\n')
    env['MOON_WORK'] = str(manifest)
    commands = [{'label': 'explicit-workspace-manifest', 'path': str(manifest), 'sha256': sha(manifest), 'MOON_WORK': str(manifest)}]

    def moon(label, arguments):
        run = subprocess.run([args.moon, *arguments], cwd=workspace, env=env, capture_output=True)
        (output / (label + '.stdout.txt')).write_bytes(run.stdout)
        (output / (label + '.stderr.txt')).write_bytes(run.stderr)
        commands.append({'label': label, 'args': arguments, 'exit_code': run.returncode})
        assert run.returncode == 0, (label, run.stderr.decode('utf-8', errors='replace'))

    fixture = ROOT / 'verification/clade_cases.json'
    fixture_hash = sha(fixture)
    data = json.loads(fixture.read_text(encoding='utf-8'))
    inputs = output / 'inputs'
    inputs.mkdir()
    immutable = {}

    def saved_input(name, suffix, text):
        path = inputs / (name + suffix)
        path.write_bytes(text.encode('utf-8'))
        immutable[str(path)] = sha(path)
        return path

    for case in data['fixtures'] + data['errors']:
        if case['newick'] is not None:
            saved_input(case['name'], '.newick', case['newick'])
    requests = []
    for case in data['fixtures']:
        for query in case['queries']:
            name = case['name'] + '-' + query['name']
            path = saved_input(name, '.taxa.json', json.dumps(query['taxa'], ensure_ascii=False))
            requests.append((name, case, query, path))
    error_inputs = {}
    for case in data['errors']:
        if not case.get('omitTaxa'):
            text = case.get('taxaJSON', json.dumps(case['taxa'], ensure_ascii=False))
            error_inputs[case['name']] = saved_input(case['name'], '.taxa.json', text)
    runs, compiled, checks = [], [], []
    for target in ['js', 'wasm-gc']:
        moon('build-' + target, ['-C', 'receiver', '--target-dir', str(build), 'build', '.', '--target', target, '--deny-warn', '--frozen'])
        extension = 'js' if target == 'js' else 'wasm'
        relative_main = 'example/clade-review/clade-review.' + extension
        artifact = build / target / 'debug/build' / relative_main
        runner = shutil.which('node') if target == 'js' else args.moonrun
        for relative in [relative_main, 'liubin-dev-2/phylo/phylo.mi', 'liubin-dev-2/phylo/phylo.core']:
            path = build / target / 'debug/build' / relative
            assert path.is_file(), path
            compiled.append({'target': target, 'artifact': relative, 'path': str(path), 'sha256': sha(path), 'bytes': path.stat().st_size})

        def call(name, tree_path, taxa_path):
            process_env = env.copy()
            process_env.pop('PHYLO_CLADE_TREE', None)
            process_env.pop('PHYLO_CLADE_TAXA', None)
            if tree_path is not None:
                process_env['PHYLO_CLADE_TREE'] = tree_path.read_text(encoding='utf-8')
            if taxa_path is not None:
                process_env['PHYLO_CLADE_TAXA'] = taxa_path.read_text(encoding='utf-8')
            run = subprocess.run([runner, str(artifact)], cwd=workspace, env=process_env, capture_output=True, timeout=30)
            stdout = output / (target + '-' + name + '.stdout.json')
            stdout.write_bytes(run.stdout)
            (output / (target + '-' + name + '.stderr.txt')).write_bytes(run.stderr)
            assert run.returncode == 0 and not run.stderr, (name, run.stderr)
            value = json.loads(run.stdout)
            runs.append({'target': target, 'case': name, 'artifactSHA256': sha(artifact), 'stdoutSHA256': sha(stdout), 'ok': value['ok']})
            return value

        for name, case, query, taxa_path in requests:
            value = call(name, inputs / (case['name'] + '.newick'), taxa_path)
            checks.append(dict(target=target, case=name, **validate(value, case, query)))
        for case in data['errors']:
            tree_path = inputs / (case['name'] + '.newick') if case['newick'] is not None else None
            value = call(case['name'], tree_path, error_inputs.get(case['name']))
            assert value['ok'] is False and value['error'] == case['error'], (case['name'], value)
            if 'detail' in case:
                assert value['detail'] == case['detail'], (case['name'], value)
            if 'detailPrefix' in case:
                assert value['detail'].startswith(case['detailPrefix']), (case['name'], value)
    assert sha(fixture) == fixture_hash
    assert all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = {'status': 'passed', 'publicModule': 'example/clade-review', 'libraryDependency': 'liubin-dev-2/phylo@0.1.0 via local workspace',
              'privateImports': False, 'oracle': data['oracle'], 'fixtureSHA256': fixture_hash, 'copiedSource': copied,
              'commands': commands, 'compiled': compiled, 'runs': runs, 'count': len(runs), 'independentChecks': checks,
              'inputSHA256': immutable, 'adoptionBoundary': 'Self-authored runnable public-package clade review only; no third-party adoption or deployed viewer evidence'}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'passed', 'publicCladeCalls': len(runs), 'independentCladeReviews': len(checks)}))


if __name__ == '__main__':
    main()
