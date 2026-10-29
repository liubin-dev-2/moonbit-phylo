"""Exercise the configurable selected-tree artifact and complete source lineage.

All complete original/projected graphs, old mappings, paths, root histories and
exported Newick bytes are literal before-edit facts. No pruning/summing oracle
implementation or scientific reference generator is run. Stage new files first.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text(path):
    return path.read_bytes().decode('utf-8')


def graph(actual, root, hand_rows):
    nodes = {row['id']: row for row in actual}
    hand = {row['role']: row for row in hand_rows}
    assert len(nodes) == len(actual) == len(hand)
    roots = [role for role, row in hand.items() if row['parent'] is None]
    assert len(roots) == 1
    roles, pending = {roots[0]: root}, roots.copy()
    while pending:
        role = pending.pop()
        expected, found = hand[role], nodes[roles[role]]
        assert found.get('label') == expected['label'] and found['comments'] == expected['comments']
        assert len(found['children']) == len(expected['children'])
        if expected['length'] is None:
            assert 'length' not in found
        else:
            assert struct.pack('>d', found['length']) == struct.pack('>d', expected['length'])
        for child, child_id in zip(expected['children'], found['children']):
            assert child not in roles
            roles[child] = child_id
            pending.append(child)
    assert set(roles) == set(hand) and set(nodes) == set(range(len(nodes)))
    for role, row in hand.items():
        assert nodes[roles[role]].get('parent') == (roles[row['parent']] if row['parent'] else None)
    return roles


def success(value, case):
    assert value['ok'] is True and value['source_unchanged'] is True and value['requested_taxa'] == case['retain']
    for prefix in ['source', 'pruned']:
        assert value[prefix + '_rooting'] == case['rooting'] and value[prefix + '_tree_comments'] == case['treeComments']
    before = graph(value['original_nodes'], value['source_root_id'], case['nodes'])
    after = graph(value['pruned_nodes'], value['pruned_root_id'], case['expectedNodes'])
    assert set(case['expectedMapping']) == set(before) and set(case['expectedPaths']) == set(after)
    mapping = [None] * len(before)
    for old_role, target_role in case['expectedMapping'].items():
        mapping[before[old_role]] = after[target_role] if target_role is not None else None
    paths = [None] * len(after)
    for role, original_roles in case['expectedPaths'].items():
        paths[after[role]] = [before[old] for old in original_roles]
    taxa = sorted([n['label'] for n in case['expectedNodes'] if not n['children']], key=lambda s: s.encode('utf-16-be'))
    # Unchanged core ToJson for Option: Some(id) -> [id], None -> null.
    expected_witness = dict(old_to_new=[None if id_ is None else [id_] for id_ in mapping], retained_taxa=taxa, edge_paths=paths, diameter_endpoints=[], split_edge=[])
    assert value['witness'] == expected_witness, (case['name'], value['witness'], expected_witness)
    targets = {n['role']: n for n in case['expectedNodes']}
    old_for_target = {target: old for old, target in case['expectedMapping'].items() if target is not None}
    role_for_id = {id_: role for role, id_ in after.items()}
    expected_lineages = []
    for node in value['pruned_nodes']:
        role = role_for_id[node['id']]
        parent = targets[role]['parent']
        if parent is not None:
            child_ids = [before[r] for r in case['expectedPaths'][role]]
            expected_lineages.append(dict(target_parent_id=after[parent], target_child_id=after[role],
                                          source_node_ids=[before[old_for_target[parent]], *child_ids], source_edge_ids=child_ids))
    assert value['edge_lineage'] == expected_lineages and len(expected_lineages) == len(after) - 1
    root_role = next(r for r, n in targets.items() if n['parent'] is None)
    history = [before[r] for r in case['expectedPaths'][root_role]]
    original = {n['id']: n for n in value['original_nodes']}
    assert value['root_history'] == history and value['root_history_nodes'] == [original[id_] for id_ in history]
    for row in expected_lineages:
        assert row['target_child_id'] != value['pruned_root_id']
        for parent_id, child_id in zip(row['source_node_ids'], row['source_node_ids'][1:]):
            assert original[child_id]['parent'] == parent_id
    assert value['pruned_newick'] == case['expectedNewick']
    return dict(originalNodes=len(before), projectedNodes=len(after), sourceMappings=len(mapping), witnessPathVertices=sum(map(len, paths)),
                edgeLineages=len(expected_lineages), rootHistoryVertices=len(history), originalRoles=before, projectedRoles=after)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--moon', default='moon')
    parser.add_argument('--moonrun', required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    workspace = output / 'workspace'
    product, receiver = workspace / 'product', workspace / 'receiver'
    product.mkdir(parents=True)
    env = os.environ.copy(); env['PYTHONDONTWRITEBYTECODE'] = '1'
    genv = {k: v for k, v in env.items() if not k.startswith('GIT_')}; genv.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    names = sorted(name for name in subprocess.check_output(['git', '-c', 'core.autocrlf=false', 'ls-files', '-z'], cwd=ROOT, env=genv).decode().split('\0') if name)
    assert 'examples/prune_export/main.mbt' in names and 'verification/prune_export_cases.json' in names, 'Stage new files first'
    copied = []
    for name in names:
        dest = product / name; dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest); assert sha(dest) == sha(ROOT / name)
        copied.append(dict(path=name, sha256=sha(dest)))
    shutil.copytree(product / 'examples/prune_export', receiver)
    manifest = workspace / 'moon.work'; manifest.write_text('members = ["./product", "./receiver"]\n', encoding='utf-8', newline='\n')
    env['MOON_WORK'] = str(manifest)
    build = workspace / 'build'
    commands = [dict(label='explicit-workspace', path=str(manifest), sha256=sha(manifest))]

    def save(name, value):
        (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')

    def moon(label, arguments):
        q = subprocess.run([args.moon, *arguments], cwd=workspace, env=env, capture_output=True)
        (output / (label + '.stdout.txt')).write_bytes(q.stdout); (output / (label + '.stderr.txt')).write_bytes(q.stderr)
        commands.append(dict(label=label, args=arguments, exit_code=q.returncode, status='passed' if q.returncode == 0 else 'failed'))
        save('commands-progress.json', commands)
        assert q.returncode == 0, (label, q.stderr.decode('utf-8', errors='replace'))

    fixture = ROOT / 'verification/prune_export_cases.json'; fixture_hash = sha(fixture); data = json.loads(text(fixture))
    inputs, exports = output / 'inputs', output / 'exports'; inputs.mkdir(); exports.mkdir()
    immutable, paths = {}, {}
    for case in data['cases'] + data['errors']:
        tree, retain = None, None
        if case['newick'] is not None:
            tree = inputs / (case['name'] + '.newick'); tree.write_bytes(case['newick'].encode('utf-8')); immutable[str(tree)] = sha(tree)
        if not case.get('omitRetain'):
            retain = inputs / (case['name'] + '.retain.json'); retain.write_bytes(case.get('retainJSON', json.dumps(case['retain'], ensure_ascii=True)).encode('utf-8')); immutable[str(retain)] = sha(retain)
        paths[case['name']] = tree, retain
    runs, compiled, checks, exported_files, expected_errors = [], [], [], [], []
    for target in ['js', 'wasm-gc']:
        common = ['-C', 'receiver', '--target-dir', str(build)]
        moon('check-' + target, common + ['check', '--target', target, '--deny-warn', '--frozen'])
        moon('build-' + target, common + ['build', '.', '--target', target, '--deny-warn', '--frozen'])
        extension = 'js' if target == 'js' else 'wasm'
        relative = 'example/prune-export/prune-export.' + extension; base = build / target / 'debug/build'
        for name in [relative, 'liubin-dev/phylo/phylo.mi', 'liubin-dev/phylo/phylo.core']:
            path = base / name; assert path.is_file(), path
            compiled.append(dict(target=target, artifact=name, path=str(path), bytes=path.stat().st_size, sha256=sha(path)))
        artifact = base / relative; runner = shutil.which('node') if target == 'js' else args.moonrun
        for case in data['cases'] + data['errors']:
            tree, retain = paths[case['name']]; process_env = env.copy()
            for key in ['PHYLO_PRUNE_TREE', 'PHYLO_PRUNE_RETAIN']: process_env.pop(key, None)
            if tree is not None: process_env['PHYLO_PRUNE_TREE'] = text(tree)
            if retain is not None: process_env['PHYLO_PRUNE_RETAIN'] = text(retain)
            q = subprocess.run([runner, str(artifact)], cwd=workspace, env=process_env, capture_output=True, timeout=30)
            stem = target + '-' + case['name']; stdout, stderr = output / (stem + '.stdout.json'), output / (stem + '.stderr.txt')
            stdout.write_bytes(q.stdout); stderr.write_bytes(q.stderr)
            out_hash, err_hash = hashlib.sha256(q.stdout).hexdigest(), hashlib.sha256(q.stderr).hexdigest()
            assert sha(stdout) == out_hash and sha(stderr) == err_hash
            row = dict(target=target, case=case['name'], exit_code=q.returncode, status='captured_pending_assertions', artifact=str(artifact), artifactSHA256=sha(artifact),
                       stdout=str(stdout), stderr=str(stderr), stdoutSHA256=out_hash, stderrSHA256=err_hash, treeInput=str(tree) if tree else None, retainInput=str(retain) if retain else None)
            runs.append(row); save('calls-progress.json', runs)
            assert q.returncode == 0 and not q.stderr, (stem, q.stderr)
            value = json.loads(q.stdout)
            if 'error' in case:
                assert value['ok'] is False and value['error'] == case['error'], (stem, value)
                if 'detailPrefix' in case: assert value['detail'].startswith(case['detailPrefix'])
                if case['error'] == 'prune_error':
                    assert value['source_unchanged'] is True and value['requested_taxa'] == case['retain']
                    roots = [n['id'] for n in value['original_nodes'] if n.get('parent') is None]
                    assert len(roots) == 1; graph(value['original_nodes'], roots[0], data['cases'][0]['nodes'])
                row['status'] = 'passed_expected_api_error'; expected_errors.append(dict(target=target, case=case['name'], error=case['error']))
            else:
                checked = success(value, case)
                exported = exports / (stem + '.newick'); exported.write_bytes(value['pruned_newick'].encode('utf-8'))
                expected_bytes = case['expectedNewick'].encode('utf-8'); assert exported.read_bytes() == expected_bytes
                exported_files.append(dict(target=target, case=case['name'], path=str(exported), sha256=sha(exported), bytes=len(expected_bytes), stdoutSHA256=out_hash, completeLiteralCanonicalBytesEqual=True))
                checks.append(dict(target=target, case=case['name'], **checked)); row['status'] = 'passed_expected_success'
            save('calls-progress.json', runs)
    assert sha(fixture) == fixture_hash and all(sha(Path(path)) == expected for path, expected in immutable.items())
    save('RESULT.json', dict(status='passed', publicModule='example/prune-export', dependency='Only public liubin-dev/phylo@0.1.0 via local workspace', privateImports=False,
                            oracle=data['oracle'], fixtureSHA256=fixture_hash, copiedSource=copied, commands=commands, compiled=compiled, runs=runs, count=len(runs), independentChecks=checks,
                            expectedErrors=expected_errors, exports=exported_files, originalInputSHA256=immutable,
                            adoptionBoundary='Self-authored real configurable pruning artifact consumer; complete literal export readback, no product reparse/new science/native host/external adoption claim'))
    print(json.dumps(dict(status='passed', actualProcessCalls=len(runs), completeExports=len(exported_files), expectedAPIErrors=len(expected_errors))))


if __name__ == '__main__':
    main()
