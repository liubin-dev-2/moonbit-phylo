"""Finite new chain audit on existing compiled artifacts; never builds code.

Literal, self-authored facts distinguish a root taxon, a unary root path and
zero-length added branches. Only a prior independent audit helper is reused.
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
from plan_chain_review import audit

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def document(source, baseline, pool, count, order, gain, step_gains):
    return {"schema": "phylo/faith-pd-greedy-plan/v1", "tree_newick": source,
            "baseline_taxa": baseline, "candidate_taxa": pool, "limit": str(count),
            "expected_added_taxa": order, "expected_gain": gain, "expected_step_gains": step_gains}


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
    node, moonrun = shutil.which("node"), shutil.which("moonrun")
    assert node and moonrun, "installed Node and MoonBit runtime must already be on PATH"
    artifacts = {"js": args.js_artifact.resolve(), "wasm-gc": args.wasm_artifact.resolve()}
    identities = [{"target": target, "path": str(path), "sha256": sha(path)} for target, path in artifacts.items()]
    commands = []
    def invoke(target, name, path):
        env = os.environ.copy()
        for key in ["PHYLO_PLAN_REQUEST", "PHYLO_PLAN_DOCUMENT", "PHYLO_PLAN_ADDITIONAL_LIMIT", "PHYLO_PLAN_CHAIN"]:
            env.pop(key, None)
        env["PHYLO_PLAN_CHAIN"] = path.read_bytes().decode("utf-8")
        runner = node if target == "js" else moonrun
        command = [runner, str(artifacts[target]), "review-chain"]
        result = subprocess.run(command, cwd=output, env=env, capture_output=True, timeout=60)
        stdout, stderr = output / f"{name}-{target}.stdout.json", output / f"{name}-{target}.stderr.log"
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        commands.append({"target": target, "command": command, "cwd": str(output), "input": str(path),
            "input_sha256": sha(path), "exit_code": result.returncode, "stdout": str(stdout),
            "stdout_sha256": sha(stdout), "stderr": str(stderr)})
        (output / "commands.json").write_text(json.dumps(commands, indent=2)+"\n", encoding="utf-8")
        assert result.returncode == 0, (command, result.stderr)
        return json.loads(result.stdout)

    root_source = "[&R]Solo:999;"
    root_chain = [document(root_source, [], ["Solo"], 1, ["Solo"], 0.0, [0.0]),
                  document(root_source, ["Solo"], ["Solo"], 0, [], 0.0, [])]
    unary_source = "[&R](Solo:999)Study:123;"
    unary_chain = [document(unary_source, [], ["Solo"], 1, ["Solo"], 999.0, [999.0]),
                   document(unary_source, ["Solo"], ["Solo"], 0, [], 0.0, [])]
    zero_source = "[&R](Iota:0,Kappa:0,Lambda:0)Study:100;"
    zero_chain = [document(zero_source, ["Iota"], ["Lambda", "Kappa"], 1, ["Kappa"], 0.0, [0.0]),
                  document(zero_source, ["Iota", "Kappa"], ["Lambda", "Kappa"], 1, ["Lambda"], 0.0, [0.0])]
    unary_edges = [{"descendant_taxa": ["Solo"], "length": 999.0}]
    zero_edges = [{"descendant_taxa": [label], "length": 0.0} for label in ["Iota", "Kappa", "Lambda"]]
    cases = [("root-is-only-taxon", root_chain, [], 1, ["Solo"], 0, 0.0, 999.0),
             ("single-tip-unary-study-root", unary_chain, unary_edges, 2, ["Solo"], 1, 999.0, 123.0),
             ("zero-length-new-branches", zero_chain, zero_edges, 4, ["Iota", "Kappa", "Lambda"], 2, 0.0, 100.0)]
    valid, inputs = [], []
    for name, chain, edges, node_count, taxa, edge_count, gain, root_stem in cases:
        path = output / f"{name}.chain.json"
        path.write_text(json.dumps(chain, indent=2)+"\n", encoding="utf-8")
        inputs.append({"path": str(path), "sha256": sha(path)})
        for target in ["js", "wasm-gc"]:
            response = invoke(target, name, path)
            result = audit(response, chain, edges)
            nodes = response["nodes"]
            assert len(nodes) == node_count and sorted(n["id"] for n in nodes) == list(range(node_count))
            assert sorted(n["label"] for n in nodes if not n["children"]) == sorted(taxa)
            root = next(n for n in nodes if n.get("parent") is None)
            assert root["length"] == root_stem
            cumulative = response["cumulative"]["report"]
            assert cumulative["gain"] == gain and len(cumulative["edge_ids"]) == edge_count
            if name == "root-is-only-taxon":
                assert root["label"] == "Solo" and not root["children"]
                assert cumulative["added_taxa"] == ["Solo"] and cumulative["edge_ids"] == []
            if name == "single-tip-unary-study-root":
                assert root["label"] == "Study" and len(root["children"]) == 1
            if name == "zero-length-new-branches":
                assert cumulative["added_taxa"] == ["Kappa", "Lambda"]
            valid.append({"case": name, "target": target, "root_stem_excluded": root_stem,
                          "new_edge_count": edge_count, **result})

    no_choice = copy.deepcopy(root_chain)
    no_choice[0]["expected_added_taxa"] = []
    no_choice[0]["expected_step_gains"] = []
    root_stem_claim = copy.deepcopy(root_chain)
    root_stem_claim[0]["expected_gain"] = 999.0
    rejected = []
    for name, chain, detail in [("zero-gain-erased-choice", no_choice, "expected_added_taxa"),
                                ("root-stem-claimed-as-gain", root_stem_claim, "expected_gain")]:
        path = output / f"invalid-{name}.chain.json"
        path.write_text(json.dumps(chain), encoding="utf-8")
        for target in ["js", "wasm-gc"]:
            response = invoke(target, name, path)
            assert response["ok"] is False and response["error"] == "stage_failed"
            assert type(response["stage_index"]) is int and response["stage_index"] == 0
            assert response["cause"]["error"] == "claim_mismatch" and detail in response["cause"]["detail"]
            rejected.append({"case": name, "target": target, "cause": "claim_mismatch", "detail": detail})
    assert all(sha(Path(row["path"])) == row["sha256"] for row in inputs)
    assert all(sha(Path(row["path"])) == row["sha256"] for row in identities)
    receipt = {"status": "passed", "valid_reviews": valid, "false_claim_rejections": rejected,
        "commands": commands, "artifacts": identities, "inputs_unchanged": inputs,
        "runners": {"node": node, "moonrun": moonrun}, "build_or_compiler_invocations": 0,
        "new_runtime_feature_or_repair": False, "old_mains_scenarios_generators_replayed": False,
        "reference": "self-authored literal nonroot edge facts; existing independent Fraction/edge audit helper only; no sum/left-fold assumption"}
    (output / "consumer-readback.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "new_semantic_cases": len(cases), "backend_reviews": len(valid),
                      "false_claim_rejections": len(rejected), "frozen_artifact_executions": len(commands), "builds": 0}))


if __name__ == "__main__":
    main()
