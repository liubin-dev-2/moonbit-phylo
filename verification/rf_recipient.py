"""One-request/one-response RF executable: literal independent full reports.

No RF algorithm or product output creates these expectations. Saved source
Newick files are the inputs to real new processes; their bytes stay unchanged.
"""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--artifact-dir', required=True)
    parser.add_argument('--moonrun', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    inputs = output / 'original-inputs'; inputs.mkdir(exist_ok=True)
    fixture = ROOT / 'verification/rf_recipient_cases.json'
    fixture_hash = sha(fixture); data = json.loads(fixture.read_text(encoding='utf-8'))
    immutable = {}
    for case in data['cases'] + data['errors']:
        for side in ['left', 'right']:
            if side in case:
                path = inputs / (case['name'] + '-' + side + '.newick')
                path.write_bytes(case[side].encode('utf-8')); immutable[str(path)] = sha(path)
    runs = []; outputs = {}
    for target in ['js', 'wasm-gc']:
        artifact = Path(args.artifact_dir).resolve() / target / 'debug/build/cmd/rf_compare' / ('rf_compare.js' if target == 'js' else 'rf_compare.wasm')
        runner = shutil.which('node') if target == 'js' else args.moonrun
        assert artifact.is_file() and runner
        artifact_hash = sha(artifact)

        def call(case, reverse=False):
            env = os.environ.copy()
            for key in ['PHYLO_RF_MODE', 'PHYLO_RF_LEFT', 'PHYLO_RF_RIGHT']:
                env.pop(key, None)
            if 'mode' in case:
                env['PHYLO_RF_MODE'] = case['mode']
            for side in ['left', 'right']:
                if side in case:
                    read_side = ('right' if side == 'left' else 'left') if reverse else side
                    env['PHYLO_RF_' + side.upper()] = (inputs / (case['name'] + '-' + read_side + '.newick')).read_text(encoding='utf-8')
            run = subprocess.run([runner, str(artifact)], env=env, capture_output=True, timeout=30)
            name = case['name'] + ('-reverse' if reverse else '')
            stem = output / (target + '-' + name)
            stem.with_suffix('.stdout.json').write_bytes(run.stdout); stem.with_suffix('.stderr.txt').write_bytes(run.stderr)
            assert run.returncode == 0 and not run.stderr, (name, run.returncode, run.stderr)
            assert len(run.stdout.splitlines()) == 1, 'Recipient requires exactly one JSON response'
            payload = json.loads(run.stdout)
            assert isinstance(payload.get('ok'), bool)
            runs.append({'case': name, 'target': target, 'artifact_sha256': artifact_hash,
                         'stdout_sha256': hashlib.sha256(run.stdout).hexdigest(), 'exit_code': run.returncode, 'ok': True})
            outputs[target + '-' + name] = payload
            return payload

        for case in data['cases']:
            expected = dict(case['expected'], ok=True)
            assert call(case) == expected, case['name']
            reverse = dict(expected, only_left=expected['only_right'], only_right=expected['only_left'])
            assert call(case, True) == reverse, case['name'] + '-reverse'
        for case in data['errors']:
            value = call(case)
            assert value['ok'] is False and value['error'] == case['error'] and 'distance' not in value, (case['name'], value)
            for key in ['input', 'only_left_taxa', 'only_right_taxa']:
                if key in case:
                    assert value[key] == case[key]
        assert sha(artifact) == artifact_hash
    for key, value in outputs.items():
        if key.startswith('js-'):
            assert outputs['wasm-gc-' + key[3:]] == value
    assert sha(fixture) == fixture_hash and all(sha(Path(path)) == expected for path, expected in immutable.items())
    result = {'status': 'passed', 'oracle': data['oracle'], 'fixture_sha256': fixture_hash,
              'immutable_inputs_sha256': immutable, 'runs': runs, 'count': len(runs),
              'recipient': 'Two original Newick texts, explicit mode, exactly one JSON response; no NJ/file receiver or scientific algorithm change'}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'passed', 'consumer_calls': len(runs), 'full_report_pairs': len(data['cases']), 'error_cases': len(data['errors'])}))


if __name__ == '__main__':
    main()
