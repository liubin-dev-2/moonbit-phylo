"""Multi-round continuity and origin-baseline cumulative review.

Uses new scenarios with cached independent edge facts/Fraction and only prior
helper functions. No prior adapter main, scenario or generator is executed.
"""
from collections import Counter
from fractions import Fraction
from pathlib import Path
import argparse
import copy
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys

sys.dont_write_bytecode = True
from plan_document_review import expected, bits, edge_key

ROOT = Path(__file__).resolve().parents[1]
PLAN = "phylo/faith-pd-greedy-plan/v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage_left_fold(values):
    total = 0.0
    for value in values:
        total = total + float(value)
    return total


def make_chain(source, baseline, pool, counts, edges):
    documents = []
    selected = baseline.copy()
    for count in counts:
        want = expected(edges, selected, pool, count)
        order = [s["taxon"] for s in want["steps"]]
        documents.append({"schema": PLAN, "tree_newick": source, "baseline_taxa": selected.copy(),
            "candidate_taxa": pool.copy(), "limit": str(count), "expected_added_taxa": order,
            "expected_gain": want["gain"], "expected_step_gains": [s["gain"] for s in want["steps"]]})
        selected = sorted(set(selected) | set(order))
    return documents


def audit(report, documents, edges):
    assert report["schema"] == "phylo/faith-pd-greedy-chain-review/v1" and report["ok"] is True
    assert type(report["stage_count"]) is int and report["stage_count"] == len(documents)
    assert report["documents"] == documents
    baseline = sorted(documents[0]["baseline_taxa"])
    selected, orders, gains = baseline.copy(), [], []
    for doc in documents:
        assert sorted(doc["baseline_taxa"]) == selected
        want = expected(edges, selected, doc["candidate_taxa"], int(doc["limit"]))
        order = [s["taxon"] for s in want["steps"]]
        assert order == doc["expected_added_taxa"] and bits(want["gain"]) == bits(doc["expected_gain"])
        assert [bits(s["gain"]) for s in want["steps"]] == [bits(x) for x in doc["expected_step_gains"]]
        orders.append(order)
        gains.append(want["gain"])
        selected = sorted(set(selected) | set(order))
    assert report["origin_baseline_taxa"] == baseline and report["final_selected_taxa"] == selected
    assert report["stage_added_taxa"] == orders and list(map(bits, report["stage_gains"])) == list(map(bits, gains))
    nodes = report["nodes"]
    by_id = {n["id"]: n for n in nodes}
    assert len(by_id) == len(nodes)
    for node in nodes:
        assert type(node["id"]) is int and all(type(i) is int for i in node["children"])
        if "parent" in node:
            assert type(node["parent"]) is int
    roots = [n["id"] for n in nodes if n.get("parent") is None]
    assert len(roots) == 1
    memo = {}
    def tips(node_id):
        if node_id not in memo:
            n = by_id[node_id]
            for child in n["children"]:
                assert by_id[child]["parent"] == node_id
            memo[node_id] = sorted(x for child in n["children"] for x in tips(child)) if n["children"] else [n["label"]]
        return memo[node_id]
    tips(roots[0])
    assert len(memo) == len(nodes)
    actual = {n["id"]: {"descendant_taxa": tips(n["id"]), "length": n["length"]}
              for n in nodes if n.get("parent") is not None}
    assert Counter(map(edge_key, actual.values())) == Counter(map(edge_key, edges))
    added_edges = [e for e in edges if set(e["descendant_taxa"]) & set(selected)
                   and not set(e["descendant_taxa"]) & set(baseline)]
    exact = sum((Fraction.from_float(e["length"]) for e in added_edges), Fraction())
    cumulative = report["cumulative"]
    try:
        rounded = float(exact)
    except OverflowError:
        assert cumulative["ok"] is False and cumulative["error"] == "tree_error" and "NumericOverflow" in cumulative["detail"]
        return {"stages": len(documents), "nodes": len(nodes), "orders": orders,
                "stage_gain_bits": list(map(bits, gains)), "cumulative_available": False,
                "chain_valid_despite_cumulative_overflow": True}
    assert cumulative["ok"] is True
    result = cumulative["report"]
    assert result["baseline_taxa"] == baseline and result["added_taxa"] == sorted(set(selected)-set(baseline))
    assert type(result["root_id"]) is int and result["root_id"] == roots[0]
    ids = result["edge_ids"]
    assert all(type(i) is int for i in ids) and ids == sorted(set(ids))
    assert Counter(map(edge_key, [actual[i] for i in ids])) == Counter(map(edge_key, added_edges))
    assert bits(result["gain"]) == bits(rounded)
    return {"stages": len(documents), "nodes": len(nodes), "orders": orders,
            "stage_gain_bits": list(map(bits, gains)), "cumulative_available": True,
            "gain": result["gain"], "gain_bits": bits(result["gain"]), "new_edges": len(ids)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reuse-produced-stages", action="store_true",
                        help="resume after a verifier-only failure using exactly three hash-checked producer receipts")
    args = parser.parse_args()
    output = args.output.resolve()
    assert output != ROOT and ROOT not in output.parents
    output.mkdir(parents=True, exist_ok=True)
    moon = shutil.which("moon")
    assert moon
    invocations, inputs = [], []
    def reject_constant(value):
        raise AssertionError("nonfinite JSON token: " + value)
    def invoke(target, mode, name, path=None, count=None):
        env = os.environ.copy()
        for key in ["PHYLO_PLAN_CHAIN", "PHYLO_PLAN_REQUEST", "PHYLO_PLAN_DOCUMENT", "PHYLO_PLAN_ADDITIONAL_LIMIT"]:
            env.pop(key, None)
        if path:
            key = "PHYLO_PLAN_CHAIN" if mode == "review-chain" else "PHYLO_PLAN_REQUEST" if mode == "create" else "PHYLO_PLAN_DOCUMENT"
            env[key] = path.read_bytes().decode("utf-8")
        if count is not None:
            env["PHYLO_PLAN_ADDITIONAL_LIMIT"] = str(count)
        command = [moon, "run", "cmd/plan_document", "--target", target, "--", mode]
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=60)
        stdout, stderr = output / f"{name}-{target}.stdout.json", output / f"{name}-{target}.stderr.log"
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        invocations.append({"target": target, "mode": mode, "command": command, "additional": count,
            "input": str(path) if path else None, "input_sha256": sha(path) if path else None,
            "exit_code": result.returncode, "stdout": str(stdout), "stdout_sha256": sha(stdout), "stderr": str(stderr)})
        (output / "commands.json").write_text(json.dumps(invocations, indent=2)+"\n", encoding="utf-8")
        assert result.returncode == 0, (command, result.stderr)
        return json.loads(result.stdout, parse_constant=reject_constant), stdout

    facts_path = ROOT / "testdata/diversity-golden.json"
    full = next(row for row in json.loads(facts_path.read_text())["fixtures"] if row["name"] == "real-all")
    baseline = ["Paraleptuca_chlorophthalmus", "Leptuca_stenodactylus"]
    pool = ["Austruca_sindensis", "Gelasimus_vomeris", "Leptuca_terpsichores", "Minuca_vocator",
            "Petruca_panamensis", "Tubuca_longidigitum", "Uca_maracoani"]
    request = {"schema": "phylo/faith-pd-greedy-request/v1", "tree_newick": "[&R]"+full["newick"],
               "baseline_taxa": baseline, "candidate_taxa": pool, "limit": "1"}
    request_path = output / "new-multi-round.request.json"
    request_path.write_text(json.dumps(request), encoding="utf-8")
    if args.reuse_produced_stages:
        retained = json.loads((output / "commands-initial.json").read_text())
        assert len(retained) == 3 and [r["mode"] for r in retained] == ["create", "resume", "resume"]
        assert [r["target"] for r in retained] == ["js", "wasm-gc", "js"]
        for row in retained:
            assert row["exit_code"] == 0 and sha(Path(row["stdout"])) == row["stdout_sha256"]
            assert sha(Path(row["input"])) == row["input_sha256"]
        invocations.extend(retained)
        p0, p1, p2 = [Path(row["stdout"]) for row in retained]
        first, second, third = [json.loads(p.read_bytes()) for p in [p0, p1, p2]]
    else:
        first, p0 = invoke("js", "create", "new-multi-round-stage0", request_path)
        second, p1 = invoke("wasm-gc", "resume", "new-multi-round-stage1", p0, 2)
        third, p2 = invoke("js", "resume", "new-multi-round-stage2", p1, 1)
    assert first["baseline_taxa"] == sorted(baseline) and first["candidate_taxa"] == sorted(pool)
    assert [d["limit"] for d in [first, second, third]] == ["1", "2", "1"]
    real = [first, second, third]
    for p in [request_path, p0, p1, p2]:
        inputs.append({"path": str(p), "sha256": sha(p)})

    hand_edges = [{"descendant_taxa": taxa, "length": length} for taxa, length in [
        (["North", "South"], 3.0), (["North"], 2.0), (["South"], 9.0),
        (["East", "West"], 6.0), (["East"], 5.0), (["West"], 4.0)]]
    source = "[&R]((North:2,South:9):3,(East:5,West:4):6)Stem:700;"
    hand = make_chain(source, ["North"], ["West", "East", "South"], [1, 0, 1], hand_edges)
    hand[1]["candidate_taxa"].reverse()
    hand[1]["baseline_taxa"].reverse()
    hand[1]["tree_newick"] = source.replace("North:2", "North:2.0").replace(":3,", ":3.00,")
    precision_edges = [{"descendant_taxa": [label], "length": value}
        for label, value in [("Big", 1e16), ("SmallA", 1.0), ("SmallB", 1.0)]]
    precision = make_chain("[&R](Big:10000000000000000,SmallA:1,SmallB:1);", [],
                           ["SmallB", "Big", "SmallA"], [1, 1, 1], precision_edges)
    assert stage_left_fold(doc["expected_gain"] for doc in precision) == 1e16
    huge_edges = [{"descendant_taxa": [label], "length": value}
        for label, value in [("Anchor", 1.0), ("HugeA", 1e308), ("HugeB", 1e308)]]
    huge = make_chain("[&R](Anchor:1,HugeA:1e308,HugeB:1e308);", ["Anchor"], ["HugeA", "HugeB"], [1, 1], huge_edges)
    cases = [("actual-three-round-real", real, full["edges"]), ("zero-middle-normalized-chain", hand, hand_edges),
        ("single-zero-stage", make_chain(source, ["North"], ["West", "East", "South"], [0], hand_edges), hand_edges),
        ("stage-rounding-cumulative-query", precision, precision_edges), ("valid-stages-cumulative-overflow", huge, huge_edges)]
    passed = []
    for name, documents, edges in cases:
        path = output / f"{name}.chain.json"
        if name == "actual-three-round-real" and os.name == "nt":
            shell = shutil.which("pwsh") or shutil.which("powershell")
            assert shell
            def ps(value):
                return "'" + str(value).replace("'", "''") + "'"
            script = output / "bundle-real-chain.ps1"
            script.write_text("$ErrorActionPreference = 'Stop'\n$phyloChain = @(\n"+
                "\n".join("  (Get-Content -LiteralPath "+ps(p)+" -Raw -Encoding utf8 | ConvertFrom-Json)" for p in [p0, p1, p2])+
                "\n)\nConvertTo-Json -InputObject $phyloChain -Depth 8 | Set-Content -LiteralPath "+ps(path)+" -Encoding utf8\n", encoding="utf-8")
            bundle = subprocess.run([shell, "-NoProfile", "-File", str(script)], capture_output=True, timeout=30)
            (output / "bundle.stdout.log").write_bytes(bundle.stdout)
            (output / "bundle.stderr.log").write_bytes(bundle.stderr)
            assert bundle.returncode == 0 and json.loads(path.read_bytes().decode("utf-8-sig")) == documents
        else:
            path.write_text(json.dumps(documents, ensure_ascii=False, indent=2)+"\n",
                            encoding="utf-8-sig" if name == "zero-middle-normalized-chain" else "utf-8")
        inputs.append({"path": str(path), "sha256": sha(path)})
        for target in ["js", "wasm-gc"]:
            response, _ = invoke(target, "review-chain", name, path)
            result = audit(response, documents, edges)
            if name == "stage-rounding-cumulative-query":
                assert result["gain_bits"] == bits(10000000000000002.0) and result["gain"] != stage_left_fold(response["stage_gains"])
            passed.append({"case": name, "target": target, "input_sha256": sha(path), **result})

    def changed(index, field, value):
        documents = copy.deepcopy(hand)
        documents[index][field] = value
        return documents
    disconnected_base = copy.deepcopy(hand)
    disconnected_base[1] = make_chain(source, ["North"], hand[0]["candidate_taxa"], [0], hand_edges)[0]
    disconnected_pool = changed(1, "candidate_taxa", ["West", "East"])
    disconnected_tree = changed(1, "tree_newick", source.replace("South:9", "South:10"))
    bad = [
        ("outer-json", "[", "invalid_json", None, None),
        ("outer-object", "{}", "invalid_field", None, None),
        ("empty-chain", "[]", "invalid_field", None, None),
        ("stage-object", json.dumps(["not a document"]), "stage_failed", 0, "invalid_field"),
        ("stage-version", json.dumps(changed(0, "schema", "future")), "stage_failed", 0, "unsupported_schema"),
        ("zero-stage-claim", json.dumps(changed(1, "expected_gain", 1)), "stage_failed", 1, "claim_mismatch"),
        ("baseline-disconnect", json.dumps(disconnected_base), "chain_mismatch", 1, "baseline_taxa"),
        ("pool-disconnect", json.dumps(disconnected_pool), "chain_mismatch", 1, "candidate_taxa"),
        ("source-disconnect", json.dumps(disconnected_tree), "chain_mismatch", 1, "tree_newick"),
    ]
    rejected = []
    for name, text, code, index, detail in bad:
        path = output / f"invalid-{name}.chain.json"
        path.write_text(text, encoding="utf-8")
        for target in ["js", "wasm-gc"]:
            response, _ = invoke(target, "review-chain", "invalid-"+name, path)
            assert response["ok"] is False and response["error"] == code
            if index is not None:
                assert type(response["stage_index"]) is int and response["stage_index"] == index
            if code == "stage_failed":
                assert response["cause"]["error"] == detail
            if code == "chain_mismatch":
                assert response["field"] == detail
            rejected.append({"case": name, "target": target, "error": code, "stage_index": index})
    for target in ["js", "wasm-gc"]:
        response, _ = invoke(target, "review-chain", "missing-chain")
        assert response == {"ok": False, "error": "missing_chain"}
        rejected.append({"case": "missing-chain", "target": target, "error": "missing_chain"})
    assert all(sha(Path(row["path"])) == row["sha256"] for row in inputs)
    receipt = {"status": "passed", "source_fixture": str(facts_path), "source_fixture_sha256": sha(facts_path),
        "valid_chain_reviews": passed, "rejected_chains": rejected, "inputs_unchanged": inputs, "invocations": invocations,
        "actual_producer_modes": ["create(js)", "resume(wasm-gc)", "resume(js)"],
        "verified_producer_results_retained_after_verifier_only_correction": args.reuse_produced_stages,
        "old_mains_scenarios_generators_replayed": False, "third_party_dependency": False,
        "method": "new multi-stage documents; cached independent full-edge/Fraction expectations; origin cumulative query; actual persisted bytes"}
    (output / "consumer-readback.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "new_chain_cases": len(cases), "backend_reviews": len(passed),
                      "rejections": len(rejected), "CLI_processes": len(invocations)}))


if __name__ == "__main__":
    main()
