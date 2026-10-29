"""Verify transactional leaf renames and an actual second-process Newick handoff.

All graph/target-label/rename-row facts were frozen before product edits.
Inputs and emitted Newick are preserved as original UTF-8 bytes; per-process
exit/status and full stdout/stderr hashes are explicit, not inferred metadata.
Requires tracked current sources (stage new local files before running).
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


def graph(actual, root_id, case, renamed):
    nodes = {row['id']: row for row in actual}
    hand = {row['role']: row for row in case['nodes']}
    assert len(nodes) == len(actual) == len(hand)
    roots = [role for role, row in hand.items() if row['parent'] is None]
    assert len(roots) == 1
    roles = {roots[0]: root_id}
    pending = roots.copy()
    while pending:
        role = pending.pop()
        found, expected = nodes[roles[role]], hand[role]
        label = case['expectedLabels'][role] if renamed else expected['label']
        assert found['label'] == label and found['comments'] == expected['comments']
        assert len(found['children']) == len(expected['children'])
        if expected['length'] is None:
            assert 'length' not in found
        else:
            assert struct.pack('>d', found['length']) == struct.pack('>d', expected['length'])
        for child, child_id in zip(expected['children'], found['children']):
            assert child not in roles
            roles[child] = child_id
            pending.append(child)
    assert set(roles) == set(hand)
    for role, expected in hand.items():
        assert nodes[roles[role]].get('parent') == (roles[expected['parent']] if expected['parent'] else None)
    return roles


def emitted(value, case):
    assert value['ok'] is True and value['source_unchanged'] is True and value['ownership_verified'] is True
    assert value['rooting'] == value['renamed_rooting'] == case['rooting']
    assert value['source_tree_comments'] == value['renamed_tree_comments'] == case['treeComments']
    before = graph(value['original_nodes'], value['source_root_id'], case, False)
    after = graph(value['renamed_nodes'], value['renamed_root_id'], case, True)
    assert before == after  # Declared correspondence of this particular clone.
    expected = [{'from_taxon': row['from_taxon'], 'to_taxon': row['to_taxon'],
                 'source_id': before[row['role']], 'target_id': after[row['role']]} for row in case['expectedRenames']]
    assert value['renames'] == expected
    if case['name'] == 'catalog-handoff':
        assert "'B [region]; O''Brien_😀'" in value['renamed_newick']
        assert '[old A; keep]' in value['renamed_newick'] and value['renamed_newick'].endswith(';[tree A]')
    return {'expectedRenames': expected, 'graphNodes': len(case['nodes'])}


def received(value, case, exported):
    assert value['ok'] is True and value['rooting'] == case['rooting'] and value['tree_comments'] == case['treeComments']
    graph(value['nodes'], value['root_id'], case, True)  # No cross-reparse ID equality.
    expected_taxa = sorted([case['expectedLabels'][row['role']] for row in case['nodes'] if not row['children']], key=lambda name: name.encode('utf-16-be'))
    assert value['taxa'] == expected_taxa
    assert value['tree_newick'].encode('utf-8') == exported.read_bytes()


def check_error(value, case):
    assert value['ok'] is False and value['error'] == case['error'], (case['name'], value)
    if 'taxon' in case:
        assert value['taxon'] == case['taxon']
    if 'detailPrefix' in case:
        assert value['detail'].startswith(case['detailPrefix'])
    if 'sourceLabel' in case:
        nodes = {row['id']: row for row in value['original_nodes']}
        assert nodes[value['node_id']]['label'] == case['sourceLabel'] and not nodes[value['node_id']]['children']
    if case['error'] in ['unknown_source', 'empty_target', 'duplicate_taxon']:
        assert value['source_unchanged'] is True and value['original_nodes'] and value['detail']


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
    env = os.environ.copy()
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    genv = {key: value for key, value in env.items() if not key.startswith('GIT_')}
    genv.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    names = sorted(name for name in subprocess.check_output(['git', '-c', 'core.autocrlf=false', 'ls-files', '-z'], cwd=ROOT, env=genv).decode().split('\0') if name)
    assert 'examples/taxon_rename_handoff/main.mbt' in names and 'verification/taxon_rename_cases.json' in names, 'Stage new source files first'
    copied = []
    for name in names:
        dest = product / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
        assert sha(dest) == sha(ROOT / name)
        copied.append({'path': name, 'sha256': sha(dest)})
    shutil.copytree(product / 'examples/taxon_rename_handoff', receiver)
    manifest = workspace / 'moon.work'
    manifest.write_text('members = ["./product", "./receiver"]\n', encoding='utf-8', newline='\n')
    env['MOON_WORK'] = str(manifest)
    build = workspace / 'build'
    commands = [{'label': 'explicit-workspace', 'path': str(manifest), 'sha256': sha(manifest)}]

    def moon(label, arguments):
        q = subprocess.run([args.moon, *arguments], cwd=workspace, env=env, capture_output=True)
        (output / (label + '.stdout.txt')).write_bytes(q.stdout)
        (output / (label + '.stderr.txt')).write_bytes(q.stderr)
        commands.append({'label': label, 'args': arguments, 'exit_code': q.returncode, 'status': 'passed' if q.returncode == 0 else 'failed'})
        (output / 'commands-progress.json').write_text(json.dumps(commands, indent=2) + '\n', encoding='utf-8', newline='\n')
        assert q.returncode == 0, (label, q.stderr.decode('utf-8', errors='replace'))

    fixture = ROOT / 'verification/taxon_rename_cases.json'
    fixture_hash = sha(fixture)
    data = json.loads(text(fixture))
    inputs, exports = output / 'inputs', output / 'exports'
    inputs.mkdir(); exports.mkdir()
    immutable, paths = {}, {}
    for case in data['cases'] + data['errors']:
        tree_path, map_path = None, None
        if case['newick'] is not None:
            tree_path = inputs / (case['name'] + '.newick'); tree_path.write_bytes(case['newick'].encode('utf-8')); immutable[str(tree_path)] = sha(tree_path)
        if not case.get('omitMap'):
            map_path = inputs / (case['name'] + '.map.json'); map_path.write_bytes(case.get('mapJSON', json.dumps(case['mapping'], ensure_ascii=True)).encode('utf-8')); immutable[str(map_path)] = sha(map_path)
        paths[case['name']] = (tree_path, map_path)
    for case in data['receiveErrors']:
        path = None
        if case['newick'] is not None:
            path = inputs / (case['name'] + '.newick'); path.write_bytes(case['newick'].encode('utf-8')); immutable[str(path)] = sha(path)
        paths[case['name']] = (path, None)
    runs, compiled, checks, handoffs, expected_errors = [], [], [], [], []
    for target in ['js', 'wasm-gc']:
        common = ['-C', 'receiver', '--target-dir', str(build)]
        moon('check-' + target, common + ['check', '--target', target, '--deny-warn', '--frozen'])
        moon('build-emitter-' + target, common + ['build', '.', '--target', target, '--deny-warn', '--frozen'])
        moon('build-receiver-' + target, common + ['build', 'receive', '--target', target, '--deny-warn', '--frozen'])
        extension = 'js' if target == 'js' else 'wasm'
        emitter_rel = 'example/taxon-rename-handoff/taxon-rename-handoff.' + extension
        receiver_rel = 'example/taxon-rename-handoff/receive/receive.' + extension
        base = build / target / 'debug/build'
        for relative in [emitter_rel, receiver_rel, 'liubin-dev-2/phylo/phylo.mi', 'liubin-dev-2/phylo/phylo.core']:
            path = base / relative
            assert path.is_file(), path
            compiled.append({'target': target, 'artifact': relative, 'path': str(path), 'bytes': path.stat().st_size, 'sha256': sha(path)})
        runner = shutil.which('node') if target == 'js' else args.moonrun

        def call(case, stage, tree_path, map_path=None):
            process_env = env.copy()
            for key in ['PHYLO_RENAME_TREE', 'PHYLO_RENAME_MAP', 'PHYLO_RENAMED_TREE']:
                process_env.pop(key, None)
            artifact = base / (emitter_rel if stage == 'emit' else receiver_rel)
            if tree_path is not None:
                process_env['PHYLO_RENAME_TREE' if stage == 'emit' else 'PHYLO_RENAMED_TREE'] = text(tree_path)
            if stage == 'emit' and map_path is not None:
                process_env['PHYLO_RENAME_MAP'] = text(map_path)
            q = subprocess.run([runner, str(artifact)], cwd=workspace, env=process_env, capture_output=True, timeout=30)
            stem = target + '-' + stage + '-' + case['name']
            stdout, stderr = output / (stem + '.stdout.json'), output / (stem + '.stderr.txt')
            stdout.write_bytes(q.stdout); stderr.write_bytes(q.stderr)
            out_hash, err_hash = hashlib.sha256(q.stdout).hexdigest(), hashlib.sha256(q.stderr).hexdigest()
            assert sha(stdout) == out_hash and sha(stderr) == err_hash
            row = {'target': target, 'stage': stage, 'case': case['name'], 'artifactSHA256': sha(artifact), 'exit_code': q.returncode,
                   'status': 'process_completed' if q.returncode == 0 else 'process_failed', 'stdout': str(stdout), 'stdoutSHA256': out_hash,
                   'stderr': str(stderr), 'stderrSHA256': err_hash, 'stdoutBytes': len(q.stdout), 'stderrBytes': len(q.stderr)}
            runs.append(row)
            (output / 'calls-progress.json').write_text(json.dumps(runs, indent=2) + '\n', encoding='utf-8', newline='\n')
            assert q.returncode == 0 and not q.stderr, (stem, q.stderr)
            return json.loads(q.stdout), row

        for case in data['cases']:
            source, mapping = paths[case['name']]
            value, emit_run = call(case, 'emit', source, mapping)
            checked = emitted(value, case)
            emit_run['status'] = 'passed_expected_success'
            exported = exports / (target + '-' + case['name'] + '.newick')
            export_bytes = value['renamed_newick'].encode('utf-8'); exported.write_bytes(export_bytes)
            export_hash = hashlib.sha256(export_bytes).hexdigest(); assert sha(exported) == export_hash
            received_value, receive_run = call(case, 'receive', exported)
            received(received_value, case, exported)
            receive_run['status'] = 'passed_expected_success'
            assert sha(exported) == export_hash
            handoffs.append({'target': target, 'case': case['name'], 'path': str(exported), 'sha256': export_hash, 'bytes': len(export_bytes),
                             'emitterStdoutSHA256': emit_run['stdoutSHA256'], 'receiverStdoutSHA256': receive_run['stdoutSHA256'], 'receiverOnlyHasExportedTreeInput': True})
            checks.append(dict(target=target, case=case['name'], **checked))
        for case in data['errors']:
            value, row = call(case, 'emit', *paths[case['name']]); check_error(value, case)
            row['status'] = 'passed_expected_api_error'; expected_errors.append({'target': target, 'stage': 'emit', 'case': case['name'], 'error': case['error']})
        for case in data['receiveErrors']:
            value, row = call(case, 'receive', paths[case['name']][0]); check_error(value, case)
            row['status'] = 'passed_expected_api_error'; expected_errors.append({'target': target, 'stage': 'receive', 'case': case['name'], 'error': case['error']})
    assert sha(fixture) == fixture_hash and all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = {'status': 'passed', 'publicModule': 'example/taxon-rename-handoff', 'dependency': 'Only public liubin-dev-2/phylo@0.1.0 via local workspace',
              'privateImports': False, 'oracle': data['oracle'], 'fixtureSHA256': fixture_hash, 'copiedSource': copied, 'commands': commands,
              'compiled': compiled, 'runs': runs, 'count': len(runs), 'independentChecks': checks, 'expectedErrors': expected_errors, 'handoffs': handoffs,
              'originalInputSHA256': immutable, 'adoptionBoundary': 'Self-authored real two-process raw Newick handoff, no external adoption or native file-host claim'}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({'status': 'passed', 'actualProcessCalls': len(runs), 'completeHandoffs': len(handoffs), 'expectedAPIErrors': len(expected_errors)}))


if __name__ == '__main__':
    main()
