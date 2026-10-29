"""Verify an order-only tree copy and the actual public-package export consumer.

Complete original graphs, all sibling lists and all terminal rows are literal
before-edit fixtures. No terminal-count sorting implementation is used as oracle.
Run from a Git checkout, staging new files first. Python stdlib only.
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


def graph(actual, root, case, ordered):
    nodes = {row['id']: row for row in actual}
    hand = {row['role']: row for row in case['nodes']}
    assert len(nodes) == len(actual) == len(hand)
    roots = [role for role, row in hand.items() if row['parent'] is None]
    assert len(roots) == 1
    roles = {roots[0]: root}
    pending = roots.copy()
    while pending:
        role = pending.pop()
        expected = hand[role]
        found = nodes[roles[role]]
        assert found.get('label') == expected['label'] and found['comments'] == expected['comments'], (case['name'], role, found)
        children = case['expectedChildren'][role] if ordered else expected['children']
        assert len(found['children']) == len(children)
        if expected['length'] is None:
            assert 'length' not in found
        else:
            assert struct.pack('>d', found['length']) == struct.pack('>d', expected['length'])
        for child, child_id in zip(children, found['children']):
            assert child not in roles
            roles[child] = child_id
            pending.append(child)
    assert set(roles) == set(hand)
    for role, expected in hand.items():
        assert nodes[roles[role]].get('parent') == (roles[expected['parent']] if expected['parent'] else None)
    return roles


def success(value, case):
    assert value['ok'] is True and value['source_unchanged'] is True and value['idempotent'] is True
    assert value['order'] == (case['order'] or 'ascending')
    for prefix in ['source', 'ordered', 'reparsed']:
        assert value[prefix + '_rooting'] == case['rooting']
        assert value[prefix + '_tree_comments'] == case['treeComments']
    before = graph(value['original_nodes'], value['source_root_id'], case, False)
    after = graph(value['ordered_nodes'], value['ordered_root_id'], case, True)
    received = graph(value['reparsed_nodes'], value['reparsed_root_id'], case, True)
    assert before == after  # Same-operation clone only; no equality with reparse IDs.
    labels = {row['role']: row['label'] for row in case['nodes']}
    expected = [dict(row=index, id=after[role], taxon=labels[role]) for index, role in enumerate(case['expectedTipRoles'])]
    assert value['terminal_rows'] == expected
    assert value['ordered_newick'] == value['reparsed_newick']
    return dict(graphNodes=len(case['nodes']), terminalRows=len(expected), originalRoles=before, orderedRoles=after, reparsedRoles=received)


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
    assert 'examples/ladderize_export/main.mbt' in names and 'verification/ladderize_cases.json' in names, 'Stage new files first'
    copied = []
    for name in names:
        dest = product / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
        assert sha(dest) == sha(ROOT / name)
        copied.append(dict(path=name, sha256=sha(dest)))
    shutil.copytree(product / 'examples/ladderize_export', receiver)
    manifest = workspace / 'moon.work'
    manifest.write_text('members = ["./product", "./receiver"]\n', encoding='utf-8', newline='\n')
    env['MOON_WORK'] = str(manifest)
    build = workspace / 'build'
    commands = [dict(label='explicit-workspace', path=str(manifest), sha256=sha(manifest))]

    def save(name, value):
        (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')

    def moon(label, arguments):
        q = subprocess.run([args.moon, *arguments], cwd=workspace, env=env, capture_output=True)
        (output / (label + '.stdout.txt')).write_bytes(q.stdout)
        (output / (label + '.stderr.txt')).write_bytes(q.stderr)
        commands.append(dict(label=label, args=arguments, exit_code=q.returncode, status='passed' if q.returncode == 0 else 'failed'))
        save('commands-progress.json', commands)
        assert q.returncode == 0, (label, q.stderr.decode('utf-8', errors='replace'))

    fixture = ROOT / 'verification/ladderize_cases.json'
    fixture_hash = sha(fixture)
    data = json.loads(text(fixture))
    inputs, exports = output / 'inputs', output / 'exports'
    inputs.mkdir(); exports.mkdir()
    immutable, paths = {}, {}
    for case in data['cases'] + data['errors']:
        tree, order = None, None
        if case['newick'] is not None:
            tree = inputs / (case['name'] + '.newick')
            tree.write_bytes(case['newick'].encode('utf-8')); immutable[str(tree)] = sha(tree)
        if case['order'] is not None:
            order = inputs / (case['name'] + '.order.txt')
            order.write_bytes(case['order'].encode('utf-8')); immutable[str(order)] = sha(order)
        paths[case['name']] = tree, order
    runs, compiled, checks, exported_files, expected_errors = [], [], [], [], []
    for target in ['js', 'wasm-gc']:
        common = ['-C', 'receiver', '--target-dir', str(build)]
        moon('check-' + target, common + ['check', '--target', target, '--deny-warn', '--frozen'])
        moon('build-' + target, common + ['build', '.', '--target', target, '--deny-warn', '--frozen'])
        extension = 'js' if target == 'js' else 'wasm'
        relative = 'example/ladderize-export/ladderize-export.' + extension
        base = build / target / 'debug/build'
        for name in [relative, 'liubin-dev-2/phylo/phylo.mi', 'liubin-dev-2/phylo/phylo.core']:
            path = base / name
            assert path.is_file(), path
            compiled.append(dict(target=target, artifact=name, path=str(path), bytes=path.stat().st_size, sha256=sha(path)))
        artifact = base / relative
        runner = shutil.which('node') if target == 'js' else args.moonrun
        for case in data['cases'] + data['errors']:
            tree, order = paths[case['name']]
            process_env = env.copy()
            for key in ['PHYLO_LADDER_TREE', 'PHYLO_LADDER_ORDER']:
                process_env.pop(key, None)
            if tree is not None:
                process_env['PHYLO_LADDER_TREE'] = text(tree)
            if order is not None:
                process_env['PHYLO_LADDER_ORDER'] = text(order)
            q = subprocess.run([runner, str(artifact)], cwd=workspace, env=process_env, capture_output=True, timeout=30)
            stem = target + '-' + case['name']
            stdout, stderr = output / (stem + '.stdout.json'), output / (stem + '.stderr.txt')
            stdout.write_bytes(q.stdout); stderr.write_bytes(q.stderr)
            out_hash, err_hash = hashlib.sha256(q.stdout).hexdigest(), hashlib.sha256(q.stderr).hexdigest()
            assert sha(stdout) == out_hash and sha(stderr) == err_hash
            row = dict(target=target, case=case['name'], exit_code=q.returncode, status='captured_pending_assertions', artifact=str(artifact), artifactSHA256=sha(artifact),
                       stdout=str(stdout), stderr=str(stderr), stdoutSHA256=out_hash, stderrSHA256=err_hash,
                       treeInput=str(tree) if tree else None, orderInput=str(order) if order else None)
            runs.append(row); save('calls-progress.json', runs)
            assert q.returncode == 0 and not q.stderr, (stem, q.stderr)
            value = json.loads(q.stdout)
            if 'error' in case:
                assert value['ok'] is False and value['error'] == case['error'], (stem, value)
                if 'detailPrefix' in case:
                    assert value['detail'].startswith(case['detailPrefix'])
                row['status'] = 'passed_expected_api_error'
                expected_errors.append(dict(target=target, case=case['name'], error=case['error']))
            else:
                checked = success(value, case)
                exported = exports / (stem + '.newick')
                raw = value['ordered_newick'].encode('utf-8')
                exported.write_bytes(raw)
                assert exported.read_bytes().decode('utf-8') == value['reparsed_newick']
                exported_files.append(dict(target=target, case=case['name'], path=str(exported), sha256=sha(exported), bytes=len(raw), stdoutSHA256=out_hash, actualReparsedGraphVerified=True))
                checks.append(dict(target=target, case=case['name'], **checked))
                row['status'] = 'passed_expected_success'
            save('calls-progress.json', runs)
    assert sha(fixture) == fixture_hash and all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = dict(status='passed', publicModule='example/ladderize-export', dependency='Only public liubin-dev-2/phylo@0.1.0 via local workspace', privateImports=False,
                  oracle=data['oracle'], fixtureSHA256=fixture_hash, copiedSource=copied, commands=commands, compiled=compiled, runs=runs, count=len(runs),
                  independentChecks=checks, expectedErrors=expected_errors, exports=exported_files, originalInputSHA256=immutable,
                  adoptionBoundary='Self-authored real ordered export consumer; same-process actual Newick reparse, no external adoption/new native file host/layout/renderer claim')
    save('RESULT.json', result)
    print(json.dumps(dict(status='passed', actualProcessCalls=len(runs), completeExports=len(exported_files), expectedAPIErrors=len(expected_errors))))


if __name__ == '__main__':
    main()
