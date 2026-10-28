"""Continue from a valid chain even when cumulative Double is unavailable.

One new frozen-artifact consumer chain; exact Fraction edge facts and existing
audit helpers only. No build, old scenario or stage-Double summation oracle.
"""
from fractions import Fraction
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
from plan_chain_review import audit as audit_chain
from plan_document_review import audit as audit_plan, bits

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--js-artifact", type=Path,
        default=ROOT / "_build/js/debug/build/cmd/plan_document/plan_document.js")
    parser.add_argument("--wasm-artifact", type=Path,
        default=ROOT / "_build/wasm-gc/debug/build/cmd/plan_document/plan_document.wasm")
    args = parser.parse_args()
    output = args.output.resolve()
    assert output != ROOT and ROOT not in output.parents
    output.mkdir(parents=True, exist_ok=True)
    node, moonrun, pwsh = shutil.which("node"), shutil.which("moonrun"), shutil.which("pwsh")
    assert node and moonrun and pwsh
    artifacts = {"js": args.js_artifact.resolve(), "wasm-gc": args.wasm_artifact.resolve()}
    identities = [{"target": t, "path": str(p), "sha256": sha(p)} for t, p in artifacts.items()]
    commands, inputs = [], []
    def reject_constant(value):
        raise AssertionError("nonfinite JSON token: " + value)
    def invoke(target, mode, name, path, count=None):
        env = os.environ.copy()
        for key in ["PHYLO_PLAN_REQUEST", "PHYLO_PLAN_DOCUMENT", "PHYLO_PLAN_ADDITIONAL_LIMIT", "PHYLO_PLAN_CHAIN"]:
            env.pop(key, None)
        key = "PHYLO_PLAN_REQUEST" if mode == "create" else "PHYLO_PLAN_CHAIN" if mode == "review-chain" else "PHYLO_PLAN_DOCUMENT"
        env[key] = path.read_bytes().decode("utf-8")
        if count is not None:
            env["PHYLO_PLAN_ADDITIONAL_LIMIT"] = str(count)
        command = [node if target == "js" else moonrun, str(artifacts[target]), mode]
        result = subprocess.run(command, cwd=output, env=env, capture_output=True, timeout=60)
        stdout, stderr = output / f"{name}-{target}.stdout.json", output / f"{name}-{target}.stderr.log"
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        commands.append({"target": target, "mode": mode, "command": command, "cwd": str(output),
            "input": str(path), "input_sha256": sha(path), "exit_code": result.returncode,
            "stdout": str(stdout), "stdout_sha256": sha(stdout), "stderr": str(stderr)})
        (output / "commands.json").write_text(json.dumps(commands, indent=2)+"\n", encoding="utf-8")
        assert result.returncode == 0, (command, result.stderr)
        return json.loads(result.stdout, parse_constant=reject_constant), stdout

    assert sys.float_info.mant_dig == 53 and sys.float_info.max_exp == 1024
    heavy1, heavy2 = 1.1e308, 9e307
    assert heavy1 < sys.float_info.max and heavy2 < sys.float_info.max
    exact_heavy = Fraction.from_float(heavy1) + Fraction.from_float(heavy2)
    assert exact_heavy > Fraction.from_float(sys.float_info.max)
    source = "[&R](Anchor:1,HeavyOne:1.1e308,HeavyTwo:9e307,LaterSmall:3)Study:17;"
    pool = ["LaterSmall", "HeavyTwo", "HeavyOne"]
    edges = [{"descendant_taxa": [label], "length": length} for label, length in [
        ("Anchor", 1.0), ("HeavyOne", heavy1), ("HeavyTwo", heavy2), ("LaterSmall", 3.0)]]
    request = {"schema": "phylo/faith-pd-greedy-request/v1", "tree_newick": source,
               "baseline_taxa": ["Anchor"], "candidate_taxa": pool, "limit": "1"}
    request_path = output / "partial-availability.request.json"
    request_path.write_text(json.dumps(request, indent=2)+"\n", encoding="utf-8")
    first, first_path = invoke("js", "create", "first-heavy-stage", request_path)
    assert first["expected_added_taxa"] == ["HeavyOne"] and bits(first["expected_gain"]) == bits(heavy1)
    second, second_path = invoke("wasm-gc", "resume", "second-heavy-stage", first_path, 1)
    assert second["expected_added_taxa"] == ["HeavyTwo"] and bits(second["expected_gain"]) == bits(heavy2)
    prior_chain = [first, second]
    prior_path = output / "valid-prior.chain.json"
    prior_path.write_text(json.dumps(prior_chain, indent=2)+"\n", encoding="utf-8")
    prior_report, prior_report_path = invoke("js", "review-chain", "valid-prior-unavailable-cumulative", prior_path)
    prior_audit = audit_chain(prior_report, prior_chain, edges)
    assert prior_report["ok"] is True and prior_report["cumulative"]["ok"] is False
    assert "report" not in prior_report["cumulative"] and "NumericOverflow" in prior_report["cumulative"]["detail"]

    extracted_path = output / "consumer-selected.checkpoint.json"
    state_path = output / "consumer-status.json"
    def ps(value):
        return "'" + str(value).replace("'", "''") + "'"
    script = output / "consume-partial-report.ps1"
    script.write_text("$ErrorActionPreference = 'Stop'\n"
        +"$phyloReview = Get-Content -LiteralPath "+ps(prior_report_path)+" -Raw -Encoding utf8 | ConvertFrom-Json\n"
        +"if ($phyloReview.ok -ne $true) { throw 'The plan chain is not valid' }\n"
        +"$phyloCheckpoint = $phyloReview.documents[-1]\n"
        +"ConvertTo-Json -InputObject $phyloCheckpoint -Depth 8 | Set-Content -LiteralPath "+ps(extracted_path)+" -Encoding utf8\n"
        +"$phyloStatus = @{ chain_valid = $phyloReview.ok; cumulative_available = $phyloReview.cumulative.ok; checkpoint_schema = $phyloCheckpoint.schema }\n"
        +"ConvertTo-Json -InputObject $phyloStatus | Set-Content -LiteralPath "+ps(state_path)+" -Encoding utf8\n", encoding="utf-8")
    consumer_command = [pwsh, "-NoProfile", "-File", str(script)]
    consumed = subprocess.run(consumer_command, capture_output=True, timeout=30)
    (output / "consumer.stdout.log").write_bytes(consumed.stdout)
    (output / "consumer.stderr.log").write_bytes(consumed.stderr)
    assert consumed.returncode == 0, consumed.stderr
    assert json.loads(extracted_path.read_bytes().decode("utf-8-sig")) == second
    state = json.loads(state_path.read_bytes().decode("utf-8-sig"))
    assert state == {"chain_valid": True, "cumulative_available": False, "checkpoint_schema": "phylo/faith-pd-greedy-plan/v1"}

    third, third_path = invoke("wasm-gc", "resume", "finite-stage-after-unavailable-total", extracted_path, 1)
    assert third["baseline_taxa"] == ["Anchor", "HeavyOne", "HeavyTwo"]
    assert third["candidate_taxa"] == sorted(pool) and third["limit"] == "1"
    assert third["expected_added_taxa"] == ["LaterSmall"] and third["expected_gain"] == 3
    assert third["expected_step_gains"] == [3]
    stage_report, stage_report_path = invoke("js", "review", "finite-stage-origin-edges", third_path)
    stage_audit = audit_plan(stage_report, third, edges)
    assert stage_report["plan"]["gain"] == 3 and len(stage_report["plan"]["edge_ids"]) == 1
    by_id = {n["id"]: n for n in stage_report["nodes"]}
    contribution = by_id[stage_report["plan"]["edge_ids"][0]]
    assert contribution["label"] == "LaterSmall" and contribution["length"] == 3
    for n in stage_report["nodes"]:
        assert type(n["id"]) is int and all(type(i) is int for i in n["children"])
        if "parent" in n:
            assert type(n["parent"]) is int
    assert type(stage_report["plan"]["root_id"]) is int
    assert all(type(i) is int for i in stage_report["plan"]["edge_ids"])
    assert all(type(i) is int for step in stage_report["plan"]["steps"] for i in step["edge_ids"])
    extended = prior_chain + [third]
    extended_path = output / "extended-valid.chain.json"
    extended_path.write_text(json.dumps(extended, indent=2)+"\n", encoding="utf-8")
    final_report, final_report_path = invoke("wasm-gc", "review-chain", "extended-chain-unavailable-total", extended_path)
    final_audit = audit_chain(final_report, extended, edges)
    assert final_report["ok"] is True and final_report["cumulative"]["ok"] is False
    assert final_report["origin_baseline_taxa"] == ["Anchor"] and final_report["stage_count"] == 3
    assert final_report["stage_gains"][-1] == 3 and final_report["stage_added_taxa"][-1] == ["LaterSmall"]
    assert final_report["final_selected_taxa"] == ["Anchor", "HeavyOne", "HeavyTwo", "LaterSmall"]
    for path in [request_path, first_path, second_path, prior_path, prior_report_path, extracted_path,
                 state_path, third_path, stage_report_path, extended_path, final_report_path]:
        inputs.append({"path": str(path), "sha256": sha(path)})
    assert all(sha(Path(row["path"])) == row["sha256"] for row in identities)
    receipt = {"status": "passed", "commands": commands, "artifacts": identities, "inputs": inputs,
        "prior_chain_review": prior_audit, "finite_later_stage": stage_audit, "extended_chain_review": final_audit,
        "consumer": {"command": consumer_command, "exit_code": consumed.returncode, "script": str(script),
                     "script_sha256": sha(script), "state": state, "extracted_plan_equals_verified_last_document": True},
        "reference": {"mant_dig": sys.float_info.mant_dig, "max_exp": sys.float_info.max_exp,
                      "exact_heavy_sum": str(exact_heavy), "exceeds_max": True, "later_gain": 3,
                      "all_nonroot_edge_facts": edges},
        "build_or_compiler_invocations": 0, "new_runtime_feature_or_repair": False,
        "old_mains_scenarios_generators_replayed": False, "stage_Double_sum_used_as_cumulative": False}
    (output / "consumer-readback.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "new_consumer_chains": 1, "frozen_artifact_executions": len(commands),
                      "finite_later_gain": 3, "prior_and_extended_chain_valid": True, "cumulative_available": False, "builds": 0}))


if __name__ == "__main__":
    main()
