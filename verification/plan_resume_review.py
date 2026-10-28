"""Verified saved checkpoint -> CLI resume -> opposite-backend review.

New checkpoint scenarios reuse independent Fraction/edge helpers only; old
adapter mains, scenarios, generators and product solver internals are not run.
"""
from pathlib import Path
from fractions import Fraction
import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
from plan_document_review import audit, expected, bits

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = "phylo/faith-pd-greedy-plan/v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checkpoint(source, baseline, candidates, count, edges):
    want = expected(edges, baseline, candidates, count)
    return {"schema": SCHEMA, "tree_newick": source, "baseline_taxa": baseline,
        "candidate_taxa": candidates, "limit": str(count),
        "expected_added_taxa": [s["taxon"] for s in want["steps"]],
        "expected_gain": want["gain"], "expected_step_gains": [s["gain"] for s in want["steps"]]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    assert output != ROOT and ROOT not in output.parents
    output.mkdir(parents=True, exist_ok=True)
    moon = shutil.which("moon")
    assert moon, "installed toolchain must already be on PATH"
    invocations = []

    def invoke(target, mode, name, path=None, additional=None):
        env = os.environ.copy()
        for key in ["PHYLO_PLAN_REQUEST", "PHYLO_PLAN_DOCUMENT", "PHYLO_PLAN_ADDITIONAL_LIMIT"]:
            env.pop(key, None)
        if path:
            env["PHYLO_PLAN_DOCUMENT"] = path.read_bytes().decode("utf-8")
        if additional is not None:
            env["PHYLO_PLAN_ADDITIONAL_LIMIT"] = additional
        command = [moon, "run", "cmd/plan_document", "--target", target, "--", mode]
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=60)
        stdout = output / f"{name}-{target}.stdout.json"
        stderr = output / f"{name}-{target}.stderr.log"
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        invocations.append({"target": target, "mode": mode, "additional_limit": additional,
            "command": command, "input": str(path) if path else None, "input_sha256": sha(path) if path else None,
            "exit_code": result.returncode, "stdout": str(stdout), "stdout_sha256": sha(stdout), "stderr": str(stderr)})
        (output / "commands.json").write_text(json.dumps(invocations, indent=2)+"\n", encoding="utf-8")
        assert result.returncode == 0, (command, result.stderr)
        return json.loads(result.stdout), stdout

    facts_path = ROOT / "testdata/diversity-golden.json"
    full = next(row for row in json.loads(facts_path.read_text())["fixtures"] if row["name"] == "real-all")
    real = checkpoint("[&R]"+full["newick"], ["Gelasimus_hesperiae", "Minuca_pugnax"],
        ["Tubuca_polita", "Austruca_lactea", "Minuca_pugnax", "Leptuca_speciosa", "Uca_ornata", "Tubuca_bellator", "Leptuca_panacea"],
        2, full["edges"])
    hand_edges = [{"descendant_taxa": taxa, "length": length} for taxa, length in [
        (["Oak", "Elm"], 4.0), (["Oak"], 2.0), (["Elm"], 3.0),
        (["Pine", "Fir"], 1.0), (["Pine"], 6.0), (["Fir"], 5.0)]]
    source = "[&R]((Oak:2,Elm:3):4,(Pine:6,Fir:5):1)R:500;"
    hand = checkpoint(source, ["Elm"], ["Elm", "Fir", "Oak", "Pine"], 1, hand_edges)
    assert hand["expected_added_taxa"] == ["Pine"] and hand["expected_gain"] == 7.0
    exhausted = checkpoint(source, ["Elm"], hand["candidate_taxa"], 4294967295, hand_edges)
    zero_edges = [{"descendant_taxa": [label], "length": value} for label, value in [("I", 1.0), ("J", 0.0), ("K", 0.0)]]
    zero = checkpoint("[&R](I:1,J:0,K:0)R:100;", ["I"], ["K", "J", "I"], 1, zero_edges)
    cases = [("new-real-checkpoint", real, 2, full["edges"]),
        ("hand-add-one", hand, 1, hand_edges), ("hand-add-zero", hand, 0, hand_edges),
        ("hand-add-full-UInt", hand, 4294967295, hand_edges),
        ("exhausted-checkpoint", exhausted, 5, hand_edges), ("zero-gain-next-taxon", zero, 2, zero_edges)]
    valid, expectations, original_files = [], [], []
    for name, prior, additional, edges in cases:
        prior_selected = sorted(set(prior["baseline_taxa"]) | set(prior["expected_added_taxa"]))
        want = expected(edges, prior_selected, prior["candidate_taxa"], additional)
        full_want = expected(edges, prior["baseline_taxa"], prior["candidate_taxa"], int(prior["limit"])+additional)
        assert prior["expected_added_taxa"] + [s["taxon"] for s in want["steps"]] == [s["taxon"] for s in full_want["steps"]]
        if name == "hand-add-one":
            assert [s["taxon"] for s in want["steps"]] == ["Fir"] and want["gain"] == 5.0 and full_want["gain"] == 12.0
        if name == "zero-gain-next-taxon":
            assert [s["taxon"] for s in want["steps"]] == ["K"] and want["gain"] == 0.0 and len(want["edges"]) == 1
        path = output / f"{name}.checkpoint.json"
        path.write_text(json.dumps(prior, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        original_files.append({"path": str(path), "sha256": sha(path)})
        expectations.append({"case": name, "checkpoint": prior, "additional": additional,
            "continuation": want, "origin_total_gain_bits": bits(full_want["gain"])})
        for producer, reviewer in [("js", "wasm-gc"), ("wasm-gc", "js")]:
            doc, saved = invoke(producer, "resume", f"{name}-resume", path, str(additional))
            assert set(doc) == set(prior) and doc["schema"] == SCHEMA
            assert doc["baseline_taxa"] == prior_selected
            assert doc["candidate_taxa"] == sorted(prior["candidate_taxa"])
            assert doc["limit"] == str(additional)
            assert doc["expected_added_taxa"] == [s["taxon"] for s in want["steps"]]
            assert bits(doc["expected_gain"]) == bits(want["gain"])
            response, _ = invoke(reviewer, "review", f"{name}-from-{producer}", saved)
            for node in response["nodes"]:
                assert type(node["id"]) is int and all(type(x) is int for x in node["children"])
                if "parent" in node:
                    assert type(node["parent"]) is int
            assert type(response["plan"]["root_id"]) is int and all(type(x) is int for x in response["plan"]["edge_ids"])
            assert all(type(x) is int for step in response["plan"]["steps"] for x in step["edge_ids"])
            facts = audit(response, doc, edges)
            assert response["plan"]["selected_taxa"] == sorted(set(prior["baseline_taxa"]) | set(s["taxon"] for s in full_want["steps"]))
            valid.append({"case": name, "producer": producer, "reviewer": reviewer,
                "checkpoint_sha256": sha(path), "saved_plan": str(saved), "saved_plan_sha256": sha(saved),
                "prior_order": prior["expected_added_taxa"], "additional_limit": str(additional),
                "origin_total_gain_bits": bits(full_want["gain"]), **facts})

    def changed(field, value):
        row = copy.deepcopy(hand)
        row[field] = value
        return json.dumps(row)
    invalid = []
    seed = output / "hand-add-one.checkpoint.json"
    bad_cases = [
        ("prior-invalid-json", "{", "0", "invalid_json", None),
        ("prior-version", changed("schema", "future"), "0", "unsupported_schema", "future"),
        ("prior-field", changed("expected_gain", "seven"), "0", "invalid_field", "expected_gain"),
        ("prior-domain", changed("tree_newick", "[&R](Oak:2,Elm:3,Pine,Fir:5);"), "0", "tree_error", "MissingLength"),
        ("prior-gain-before-zero", changed("expected_gain", 8), "0", "claim_mismatch", "expected_gain"),
        ("prior-order-before-zero", changed("expected_added_taxa", ["Fir"]), "0", "claim_mismatch", "expected_added_taxa"),
        ("prior-step-before-zero", changed("expected_step_gains", [8]), "0", "claim_mismatch", "expected_step_gains"),
        ("additional-limit-overflow", json.dumps(hand), "4294967296", "invalid_field", "limit"),
    ]
    huge_edges = [{"descendant_taxa": [label], "length": value}
                  for label, value in [("Anchor", 1.0), ("HugeLeft", 1e308), ("HugeRight", 1e308)]]
    assert 2 * Fraction.from_float(1e308) > Fraction.from_float(float.fromhex("0x1.fffffffffffffp+1023"))
    finite_prior = checkpoint("[&R](Anchor:1,HugeLeft:1e308,HugeRight:1e308);", ["Anchor"],
                              ["HugeLeft", "HugeRight"], 0, huge_edges)
    bad_cases.append(("finite-prior-continuation-overflow", json.dumps(finite_prior), "2", "tree_error", "NumericOverflow"))
    for name, text, count, code, detail in bad_cases:
        path = output / f"invalid-{name}.checkpoint.json"
        path.write_text(text, encoding="utf-8")
        for target in ["js", "wasm-gc"]:
            response, _ = invoke(target, "resume", f"invalid-{name}", path, count)
            assert response["ok"] is False and response["error"] == code
            if detail:
                assert detail in response["detail"]
            invalid.append({"case": name, "target": target, "additional": count, "error": code})
    for target in ["js", "wasm-gc"]:
        for name, path, count, code in [
            ("missing-document", None, "1", "missing_document"),
            ("missing-additional-limit", seed, None, "missing_additional_limit"),
        ]:
            response, _ = invoke(target, "resume", name, path, count)
            assert response == {"ok": False, "error": code}
            invalid.append({"case": name, "target": target, "error": code})
    assert all(sha(Path(row["path"])) == row["sha256"] for row in original_files)
    (output / "independent-expectations.json").write_text(json.dumps(expectations, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    receipt = {"status": "passed", "source_fixture": str(facts_path), "source_fixture_sha256": sha(facts_path),
        "valid_continuation_chains": valid, "rejected_resume_inputs": invalid, "original_checkpoints_unchanged": original_files,
        "invocations": invocations, "node_IDs_verified_integer": True,
        "old_adapter_mains_scenarios_generators_replayed": False, "third_party_dependency": False,
        "method": "new independent checkpoints; cached full-edge/Fraction facts; replay gate; saved continuation bytes reviewed by other backend"}
    (output / "consumer-readback.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "new_checkpoint_cases": len(cases), "cross_backend_chains": len(valid),
                      "rejection_checks": len(invalid), "CLI_processes": len(invocations)}))


if __name__ == "__main__":
    main()
