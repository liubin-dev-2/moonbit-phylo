"""Route CLI request/claim errors using typed field data, not display detail.

One real cross-backend create/resume/review chain and a PowerShell consumer.
Only prior independent edge/Fraction helper functions are reused.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
from plan_chain_review import audit as audit_chain

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--js-artifact', type=Path,
        default=ROOT / '_build/js/debug/build/cmd/plan_document/plan_document.js')
    parser.add_argument('--wasm-artifact', type=Path,
        default=ROOT / '_build/wasm-gc/debug/build/cmd/plan_document/plan_document.wasm')
    args = parser.parse_args()
    output = args.output.resolve()
    assert output != ROOT and ROOT not in output.parents and not output.exists()
    output.mkdir(parents=True)
    programs = {'js': shutil.which('node'), 'wasm-gc': shutil.which('moonrun')}
    pwsh = shutil.which('pwsh')
    assert all(programs.values()) and pwsh
    artifacts = {'js': args.js_artifact.resolve(), 'wasm-gc': args.wasm_artifact.resolve()}
    identities = [{'target': target, 'path': str(path), 'sha256': sha(path)} for target, path in artifacts.items()]
    commands = []

    def save(name, value):
        path = output / name
        path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
        return path

    def reject_constant(value):
        raise AssertionError('nonfinite JSON token: ' + value)

    def invoke(target, mode, name, path, count=None):
        env = os.environ.copy()
        for key in ['PHYLO_PLAN_REQUEST', 'PHYLO_PLAN_DOCUMENT', 'PHYLO_PLAN_ADDITIONAL_LIMIT', 'PHYLO_PLAN_CHAIN']:
            env.pop(key, None)
        key = 'PHYLO_PLAN_REQUEST' if mode == 'create' else 'PHYLO_PLAN_CHAIN' if mode == 'review-chain' else 'PHYLO_PLAN_DOCUMENT'
        env[key] = path.read_text(encoding='utf-8')
        if count is not None:
            env['PHYLO_PLAN_ADDITIONAL_LIMIT'] = str(count)
        command = [programs[target], str(artifacts[target]), mode]
        result = subprocess.run(command, cwd=output, env=env, capture_output=True, timeout=60)
        stdout, stderr = output / f'{name}-{target}.stdout.json', output / f'{name}-{target}.stderr.log'
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        commands.append({'target': target, 'mode': mode, 'command': command, 'cwd': str(output),
            'input': str(path), 'input_sha256': sha(path), 'additional_limit': count, 'exit_code': result.returncode,
            'stdout': str(stdout), 'stdout_sha256': sha(stdout), 'stderr': str(stderr), 'stderr_sha256': sha(stderr)})
        save('commands.json', commands)
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout, parse_constant=reject_constant), stdout

    source = '[&R]((Anchor:2,Ash:6):3,(Cypress:7,Holly:4):5)FieldStudy:31;'
    edges = [{'descendant_taxa': taxa, 'length': length} for taxa, length in [
        (['Anchor', 'Ash'], 3.0), (['Anchor'], 2.0), (['Ash'], 6.0),
        (['Cypress', 'Holly'], 5.0), (['Cypress'], 7.0), (['Holly'], 4.0)]]
    request = {'schema': 'phylo/faith-pd-greedy-request/v1', 'tree_newick': source,
        'baseline_taxa': ['Anchor'], 'candidate_taxa': ['Holly', 'Ash', 'Cypress'], 'limit': 1}
    invalid_path = save('invalid-limit.request.json', request)
    limit_errors, limit_error_paths = [], []
    for target in ['js', 'wasm-gc']:
        error, path = invoke(target, 'create', 'invalid-limit', invalid_path)
        assert error['ok'] is False and error['error'] == 'invalid_field' and error['field'] == 'limit'
        assert 'limit' in error['detail']
        limit_errors.append(error)
        limit_error_paths.append(path)
    request['limit'] = '1'
    valid_path = save('corrected.request.json', request)
    prefix, prefix_path = invoke('js', 'create', 'prefix', valid_path)
    continuation, continuation_path = invoke('wasm-gc', 'resume', 'continuation', prefix_path, 1)
    assert prefix['expected_added_taxa'] == ['Cypress'] and prefix['expected_gain'] == 12
    assert continuation['expected_added_taxa'] == ['Ash'] and continuation['expected_gain'] == 6
    assert 'field' not in prefix and 'field' not in continuation
    preserved = [{'path': str(path), 'sha256': sha(path)} for path in [prefix_path, continuation_path]]
    tampered = copy.deepcopy(continuation)
    tampered['expected_gain'] = 7
    tampered_path = save('changed-claim.plan.json', tampered)
    direct_error, direct_path = invoke('js', 'review', 'changed-claim', tampered_path)
    assert direct_error['ok'] is False and direct_error['error'] == 'claim_mismatch' and direct_error['field'] == 'expected_gain'
    bad_chain_path = save('changed-claim.chain.json', [prefix, tampered])
    chain_error, chain_error_path = invoke('wasm-gc', 'review-chain', 'changed-stage-claim', bad_chain_path)
    assert chain_error['ok'] is False and chain_error['error'] == 'stage_failed'
    assert type(chain_error['stage_index']) is int and chain_error['stage_index'] == 1 and 'field' not in chain_error
    assert chain_error['cause'] == direct_error
    good_chain_path = save('valid.chain.json', [prefix, continuation])
    good_report, good_report_path = invoke('js', 'review-chain', 'valid-history', good_chain_path)
    checked = audit_chain(good_report, [prefix, continuation], edges)
    assert checked['gain'] == 18 and checked['new_edges'] == 3 and checked['nodes'] == 7
    assert 'field' not in good_report and good_report['origin_baseline_taxa'] == ['Anchor']
    domain_request = copy.deepcopy(request)
    domain_request['candidate_taxa'] = ['Ghost']
    domain_path = save('unknown-taxon.request.json', domain_request)
    domain_error, domain_error_path = invoke('wasm-gc', 'create', 'domain-error', domain_path)
    assert domain_error['ok'] is False and domain_error['error'] == 'tree_error' and 'Ghost' in domain_error['detail']
    assert 'field' not in domain_error

    def ps(value):
        return "'" + str(value).replace("'", "''") + "'"

    state_path, script = output / 'focus-state.json', output / 'consume-error-fields.ps1'
    script.write_text("$ErrorActionPreference = 'Stop'\n"
        + "$phyloControls = @{ limit = 'limit-input'; expected_gain = 'claimed-total' }\n"
        + '$phyloLimitJS = Get-Content -LiteralPath ' + ps(limit_error_paths[0]) + ' -Raw -Encoding utf8 | ConvertFrom-Json\n'
        + '$phyloLimitWasm = Get-Content -LiteralPath ' + ps(limit_error_paths[1]) + ' -Raw -Encoding utf8 | ConvertFrom-Json\n'
        + '$phyloDirect = Get-Content -LiteralPath ' + ps(direct_path) + ' -Raw -Encoding utf8 | ConvertFrom-Json\n'
        + '$phyloChain = Get-Content -LiteralPath ' + ps(chain_error_path) + ' -Raw -Encoding utf8 | ConvertFrom-Json\n'
        + '$phyloDomain = Get-Content -LiteralPath ' + ps(domain_error_path) + ' -Raw -Encoding utf8 | ConvertFrom-Json\n'
        + "if ($phyloLimitJS.ok -ne $false -or $phyloLimitWasm.ok -ne $false -or $phyloDirect.ok -ne $false -or $phyloChain.error -ne 'stage_failed') { throw 'Expected failure diagnostics' }\n"
        + "$phyloState = @{ request_targets = @($phyloControls[$phyloLimitJS.field], $phyloControls[$phyloLimitWasm.field]); direct_target = $phyloControls[$phyloDirect.field]; stage_index = $phyloChain.stage_index; stage_target = $phyloControls[$phyloChain.cause.field]; domain_uses_general_message = -not ($phyloDomain.PSObject.Properties.Name -contains 'field') }\n"
        + 'ConvertTo-Json -InputObject $phyloState -Depth 5 | Set-Content -LiteralPath ' + ps(state_path) + ' -Encoding utf8\n', encoding='utf-8')
    assert '.detail' not in script.read_text(encoding='utf-8')
    command = [pwsh, '-NoProfile', '-File', str(script)]
    consumed = subprocess.run(command, cwd=output, capture_output=True, timeout=30)
    host_stdout, host_stderr = output / 'consumer.stdout.log', output / 'consumer.stderr.log'
    host_stdout.write_bytes(consumed.stdout)
    host_stderr.write_bytes(consumed.stderr)
    host = {'command': command, 'cwd': str(output), 'exit_code': consumed.returncode, 'script': str(script),
        'script_sha256': sha(script), 'stdout': str(host_stdout), 'stdout_sha256': sha(host_stdout),
        'stderr': str(host_stderr), 'stderr_sha256': sha(host_stderr)}
    save('host-command.json', host)
    assert consumed.returncode == 0, consumed.stderr
    state = json.loads(state_path.read_bytes().decode('utf-8-sig'))
    assert state == {'request_targets': ['limit-input', 'limit-input'], 'direct_target': 'claimed-total',
        'stage_index': 1, 'stage_target': 'claimed-total', 'domain_uses_general_message': True}
    assert all(sha(Path(row['path'])) == row['sha256'] for row in identities + preserved)
    paths = [invalid_path, valid_path, prefix_path, continuation_path, tampered_path, bad_chain_path, good_chain_path,
        good_report_path, domain_path, state_path] + limit_error_paths + [direct_path, chain_error_path, domain_error_path]
    save('consumer-readback.json', {'status': 'passed', 'commands': commands, 'artifacts': identities,
        'inputs': [{'path': str(path), 'sha256': sha(path)} for path in paths], 'original_plans_unchanged': preserved,
        'limit_errors': limit_errors, 'direct_claim_error': direct_error, 'chain_claim_error': chain_error,
        'unlocalized_domain_error': domain_error, 'consumer': dict(host, state=state), 'valid_chain_review': checked,
        'reference': {'all_nonroot_edge_facts': edges, 'first_gain': 12, 'continuation_gain': 6, 'cumulative_gain': 18},
        'consumer_parses_detail': False, 'claim_auto_repair': False, 'success_schemas_or_library_contract_changed': False,
        'old_scenarios_mains_generators_replayed': False, 'build_or_compiler_invocations': 0})
    print(json.dumps({'status': 'passed', 'program_executions': len(commands), 'PowerShell_processes': 1,
        'request_field': 'limit', 'claim_field': 'expected_gain', 'stage_index': 1,
        'detail_parsing': False, 'valid_cumulative_gain': 18, 'new_edges': 3}))


if __name__ == '__main__':
    main()
