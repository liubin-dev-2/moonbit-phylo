"""Audit an expanded candidate pool as a separate, reviewed-baseline scenario.

One new consumer chain, frozen programs and literal full-edge/Fraction facts.
Existing audit functions are reused without running old scenarios or builds.
"""
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
    identities = [{"target": target, "path": str(path), "sha256": sha(path)}
                  for target, path in artifacts.items()]
    commands = []

    def save(name, value):
        path = output / name
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

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
            "input": str(path), "input_sha256": sha(path), "additional_limit": count,
            "exit_code": result.returncode, "stdout": str(stdout), "stdout_sha256": sha(stdout),
            "stderr": str(stderr), "stderr_sha256": sha(stderr)})
        save("commands.json", commands)
        assert result.returncode == 0, (command, result.stderr)
        return json.loads(result.stdout, parse_constant=reject_constant), stdout

    source = "[&R]((Oak:2,Maple:6):4,(Pine:7,Fir:3):5,Birch:8)Study:500;"
    edges = [{"descendant_taxa": taxa, "length": length} for taxa, length in [
        (["Oak", "Maple"], 4.0), (["Oak"], 2.0), (["Maple"], 6.0),
        (["Pine", "Fir"], 5.0), (["Pine"], 7.0), (["Fir"], 3.0), (["Birch"], 8.0)]]
    request = {"schema": "phylo/faith-pd-greedy-request/v1", "tree_newick": source,
        "baseline_taxa": ["Oak"], "candidate_taxa": ["Maple", "Pine"], "limit": "1"}
    request_path = save("original.request.json", request)
    prefix, prefix_path = invoke("js", "create", "original-prefix", request_path)
    assert prefix["expected_added_taxa"] == ["Pine"] and bits(prefix["expected_gain"]) == bits(12)
    prefix_review, prefix_review_path = invoke("wasm-gc", "review", "reviewed-prefix", prefix_path)
    prefix_audit = audit_plan(prefix_review, prefix, edges)
    assert prefix_review["plan"]["selected_taxa"] == ["Oak", "Pine"]
    assert len(prefix_review["nodes"]) == 8 and prefix_audit["new_edges"] == 2
    immutable = [{"path": str(path), "sha256": sha(path)} for path in [request_path, prefix_path, prefix_review_path]]

    continuation, continuation_path = invoke("wasm-gc", "resume", "original-pool-continuation", prefix_path, 1)
    assert continuation["baseline_taxa"] == ["Oak", "Pine"]
    assert continuation["candidate_taxa"] == prefix["candidate_taxa"] == ["Maple", "Pine"]
    assert continuation["expected_added_taxa"] == ["Maple"] and bits(continuation["expected_gain"]) == bits(6)
    assert continuation["tree_newick"] == prefix["tree_newick"]

    fork_request_path = output / "changed-pool.request.json"
    state_path = output / "consumer-status.json"

    def ps(value):
        return "'" + str(value).replace("'", "''") + "'"

    script = output / "consume-reviewed-prefix.ps1"
    script.write_text("$ErrorActionPreference = 'Stop'\n"
        + "$phyloReview = Get-Content -LiteralPath " + ps(prefix_review_path) + " -Raw -Encoding utf8 | ConvertFrom-Json\n"
        + "if ($phyloReview.ok -ne $true) { throw 'The prefix plan is not valid' }\n"
        + "$phyloRequest = @{ schema = 'phylo/faith-pd-greedy-request/v1'; tree_newick = $phyloReview.document.tree_newick; baseline_taxa = @($phyloReview.plan.selected_taxa); candidate_taxa = @('Maple', 'Pine', 'Birch'); limit = '1' }\n"
        + "ConvertTo-Json -InputObject $phyloRequest -Depth 8 | Set-Content -LiteralPath " + ps(fork_request_path) + " -Encoding utf8\n"
        + "$phyloStatus = @{ prefix_valid = $phyloReview.ok; inherited_baseline = @($phyloReview.plan.selected_taxa); candidate_taxa = @($phyloRequest.candidate_taxa) }\n"
        + "ConvertTo-Json -InputObject $phyloStatus -Depth 4 | Set-Content -LiteralPath " + ps(state_path) + " -Encoding utf8\n", encoding="utf-8")
    consumer_command = [pwsh, "-NoProfile", "-File", str(script)]
    consumed = subprocess.run(consumer_command, cwd=output, capture_output=True, timeout=30)
    consumer_stdout, consumer_stderr = output / "consumer.stdout.log", output / "consumer.stderr.log"
    consumer_stdout.write_bytes(consumed.stdout)
    consumer_stderr.write_bytes(consumed.stderr)
    host = {"command": consumer_command, "cwd": str(output), "exit_code": consumed.returncode,
        "script": str(script), "script_sha256": sha(script), "input": str(prefix_review_path),
        "input_sha256": sha(prefix_review_path), "stdout": str(consumer_stdout), "stdout_sha256": sha(consumer_stdout),
        "stderr": str(consumer_stderr), "stderr_sha256": sha(consumer_stderr)}
    save("host-command.json", host)
    assert consumed.returncode == 0, consumed.stderr
    fork_request = json.loads(fork_request_path.read_bytes().decode("utf-8-sig"))
    assert fork_request == {"schema": request["schema"], "tree_newick": prefix["tree_newick"],
        "baseline_taxa": ["Oak", "Pine"], "candidate_taxa": ["Maple", "Pine", "Birch"], "limit": "1"}
    state = json.loads(state_path.read_bytes().decode("utf-8-sig"))
    assert state == {"prefix_valid": True, "inherited_baseline": ["Oak", "Pine"],
        "candidate_taxa": ["Maple", "Pine", "Birch"]}

    fork, fork_path = invoke("js", "create", "independent-changed-pool", fork_request_path)
    assert fork["baseline_taxa"] == ["Oak", "Pine"] and fork["candidate_taxa"] == ["Birch", "Maple", "Pine"]
    assert fork["tree_newick"] == prefix["tree_newick"]
    assert fork["expected_added_taxa"] == ["Birch"] and bits(fork["expected_gain"]) == bits(8)

    original_chain = [prefix, continuation]
    original_chain_path = save("original.chain.json", original_chain)
    original_report, original_report_path = invoke("wasm-gc", "review-chain", "original-history", original_chain_path)
    original_audit = audit_chain(original_report, original_chain, edges)
    assert original_report["origin_baseline_taxa"] == ["Oak"] and original_audit["gain"] == 18
    assert original_audit["new_edges"] == 3 and "Birch" not in original_report["final_selected_taxa"]

    fork_chain_path = save("independent-fork.chain.json", [fork])
    fork_report, fork_report_path = invoke("js", "review-chain", "independent-fork-history", fork_chain_path)
    fork_audit = audit_chain(fork_report, [fork], edges)
    assert fork_report["origin_baseline_taxa"] == ["Oak", "Pine"] and fork_audit["gain"] == 8
    assert fork_audit["new_edges"] == 1
    by_id = {n["id"]: n for n in fork_report["nodes"]}
    edge_id = fork_report["cumulative"]["report"]["edge_ids"][0]
    assert by_id[edge_id]["label"] == "Birch" and by_id[edge_id]["length"] == 8

    mixed_path = save("mixed-pools.chain.json", [prefix, fork])
    mixed, mixed_report_path = invoke("wasm-gc", "review-chain", "mixed-pools-rejected", mixed_path)
    assert mixed["ok"] is False and mixed["error"] == "chain_mismatch"
    assert type(mixed["stage_index"]) is int and mixed["stage_index"] == 1 and mixed["field"] == "candidate_taxa"
    for report in [prefix_review, original_report, fork_report]:
        nodes = report["nodes"]
        roots = [n for n in nodes if n.get("parent") is None]
        assert len(nodes) == 8 and len(roots) == 1 and roots[0]["label"] == "Study" and roots[0]["length"] == 500
        for n in nodes:
            assert type(n["id"]) is int and all(type(i) is int for i in n["children"])
            if "parent" in n:
                assert type(n["parent"]) is int
    assert type(prefix_review["plan"]["root_id"]) is int
    assert all(type(i) is int for i in prefix_review["plan"]["edge_ids"])
    assert all(type(i) is int for step in prefix_review["plan"]["steps"] for i in step["edge_ids"])
    assert all(sha(Path(row["path"])) == row["sha256"] for row in immutable + identities)
    paths = [request_path, prefix_path, prefix_review_path, continuation_path, fork_request_path,
        state_path, fork_path, original_chain_path, original_report_path, fork_chain_path,
        fork_report_path, mixed_path, mixed_report_path]
    receipt = {"status": "passed", "commands": commands, "artifacts": identities,
        "inputs": [{"path": str(path), "sha256": sha(path)} for path in paths],
        "original_inputs_unchanged": immutable, "prefix_review": prefix_audit,
        "original_chain_review": original_audit, "independent_fork_review": fork_audit,
        "mixed_chain_rejection": mixed, "consumer": dict(host, state=state),
        "reference": {"all_nonroot_edge_facts": edges, "root_stem_excluded": 500,
            "original_origin": ["Oak"], "fork_origin": ["Oak", "Pine"],
            "cumulative_totals_have_different_baselines": True, "scenario_ranking_claim": False},
        "build_or_compiler_invocations": 0, "new_runtime_feature_or_repair": False,
        "old_mains_scenarios_generators_replayed": False, "stage_Double_sum_used_as_cumulative": False}
    save("consumer-readback.json", receipt)
    print(json.dumps({"status": "passed", "new_consumer_chains": 1, "frozen_artifact_executions": len(commands),
        "original_continuation": "Maple", "independent_fork": "Birch", "mixed_chain": "candidate_taxa mismatch",
        "original_cumulative_gain": 18, "fork_cumulative_gain": 8, "different_origin_baselines": True, "builds": 0}))


if __name__ == "__main__":
    main()
