"""Audit persisted plan files through separate JS/Wasm-GC public consumers.

Uses cached independent descendant-edge facts and standard-library Fraction.
No old reference generator, runtime source, network or third-party dependency.
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

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = "phylo/faith-pd-greedy-plan/v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bits(value):
    return struct.pack(">d", float(value)).hex()


def edge_key(edge):
    return tuple(sorted(edge["descendant_taxa"])), bits(edge["length"])


def facts_equal(left, right):
    assert Counter(map(edge_key, left)) == Counter(map(edge_key, right))


def expected(edges, baseline, candidates, limit):
    covered = {i for i, e in enumerate(edges) if set(e["descendant_taxa"]) & set(baseline)}
    initial = covered.copy()
    eligible = set(candidates) - set(baseline)
    steps = []
    for _ in range(min(limit, len(eligible))):
        choices = []
        for taxon in eligible:
            new = {i for i, e in enumerate(edges) if taxon in e["descendant_taxa"]} - covered
            gain = sum((Fraction.from_float(edges[i]["length"]) for i in new), Fraction())
            choices.append((-gain, taxon, new))
        neg_gain, taxon, new = min(choices, key=lambda c: (c[0], c[1]))
        steps.append({"taxon": taxon, "gain": float(-neg_gain),
                      "edges": [edges[i] for i in sorted(new)]})
        covered |= new
        eligible.remove(taxon)
    added = [edges[i] for i in sorted(covered - initial)]
    gain = float(sum((Fraction.from_float(e["length"]) for e in added), Fraction()))
    return {"steps": steps, "gain": gain, "edges": added}


def document(source, baseline, candidates, limit, oracle):
    return {"schema": SCHEMA, "tree_newick": source,
            "baseline_taxa": baseline, "candidate_taxa": candidates, "limit": str(limit),
            "expected_added_taxa": [s["taxon"] for s in oracle["steps"]],
            "expected_gain": oracle["gain"],
            "expected_step_gains": [s["gain"] for s in oracle["steps"]]}


def audit(response, doc, edges):
    assert response["schema"] == "phylo/faith-pd-greedy-review/v1" and response["ok"] is True
    assert response["document"] == doc
    nodes = response["nodes"]
    by_id = {n["id"]: n for n in nodes}
    assert len(by_id) == len(nodes)
    roots = [n["id"] for n in nodes if n.get("parent") is None]
    assert len(roots) == 1
    descendants = {}

    def leaves(node_id):
        if node_id not in descendants:
            n = by_id[node_id]
            for child in n["children"]:
                assert by_id[child]["parent"] == node_id
            descendants[node_id] = sorted(
                x for child in n["children"] for x in leaves(child)
            ) if n["children"] else [n["label"]]
        return descendants[node_id]

    leaves(roots[0])
    assert len(descendants) == len(nodes)
    actual = {n["id"]: {"descendant_taxa": leaves(n["id"]), "length": n["length"]}
              for n in nodes if n.get("parent") is not None}
    facts_equal(actual.values(), edges)
    oracle = expected(edges, doc["baseline_taxa"], doc["candidate_taxa"], int(doc["limit"]))
    plan = response["plan"]
    assert plan["root_id"] == roots[0] and plan["limit"] == int(doc["limit"])
    assert plan["baseline_taxa"] == sorted(doc["baseline_taxa"])
    assert plan["candidate_taxa"] == sorted(set(doc["candidate_taxa"]) - set(doc["baseline_taxa"]))
    order = [s["taxon"] for s in oracle["steps"]]
    assert plan["added_taxa"] == order
    assert plan["selected_taxa"] == sorted(set(doc["baseline_taxa"]) | set(order))
    assert bits(plan["gain"]) == bits(oracle["gain"])
    assert plan["edge_ids"] == sorted(set(plan["edge_ids"]))
    facts_equal([actual[i] for i in plan["edge_ids"]], oracle["edges"])
    assert len(plan["steps"]) == len(oracle["steps"])
    used = set()
    for step, want in zip(plan["steps"], oracle["steps"]):
        assert step["taxon"] == want["taxon"] and bits(step["gain"]) == bits(want["gain"])
        ids = step["edge_ids"]
        assert ids == sorted(set(ids)) and not used.intersection(ids)
        facts_equal([actual[i] for i in ids], want["edges"])
        used.update(ids)
    assert used == set(plan["edge_ids"])
    return {"nodes": len(nodes), "order": order, "gain": plan["gain"],
            "gain_bits": bits(plan["gain"]), "new_edges": len(used)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    assert output != ROOT and ROOT not in output.parents, "keep receipts outside source"
    output.mkdir(parents=True, exist_ok=True)
    moon = shutil.which("moon")
    assert moon, "MoonBit toolchain must already be on PATH"
    invocations = []

    def invoke(target, mode, name, path=None):
        env = os.environ.copy()
        env.pop("PHYLO_PLAN_DOCUMENT", None)
        if path is not None:
            # Read the actual saved bytes, not an in-memory object or shell literal.
            env["PHYLO_PLAN_DOCUMENT"] = path.read_bytes().decode("utf-8")
        command = [moon, "run", "cmd/plan_document", "--target", target, "--", mode]
        run = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=60)
        stdout = output / f"{name}-{target}.stdout.json"
        stderr = output / f"{name}-{target}.stderr.log"
        stdout.write_bytes(run.stdout)
        stderr.write_bytes(run.stderr)
        invocations.append({"target": target, "mode": mode, "input": str(path) if path else None,
                            "input_sha256": sha(path) if path else None, "command": command,
                            "exit_code": run.returncode, "stdout": str(stdout),
                            "stdout_sha256": sha(stdout), "stderr": str(stderr)})
        assert run.returncode == 0, (command, run.stderr)
        return json.loads(run.stdout), stdout

    source_path = ROOT / "testdata/diversity-greedy-golden.json"
    facts_path = ROOT / "testdata/diversity-golden.json"
    rows = {r["name"]: r for r in json.loads(source_path.read_text())["fixtures"]}
    facts = {r["name"]: r for r in json.loads(facts_path.read_text())["fixtures"]}
    cases = []
    for name in ["base-0-limit-2", "base-5-limit-2", "real-1"]:
        row = rows[name]
        edges = facts["real-all" if name.startswith("real") else "small-0-subset-15"]["edges"]
        oracle = expected(edges, row["baseline"], row["candidates"], row["limit"])
        assert bits(oracle["gain"]) == row["gain_bits"]
        assert [s["taxon"] for s in oracle["steps"]] == row["order"]
        assert [bits(s["gain"]) for s in oracle["steps"]] == [s["gain_bits"] for s in row["steps"]]
        cases.append((name, document("[&R]" + row["newick"], row["baseline"], row["candidates"], row["limit"], oracle), edges))
    labels = ["龙_种", "O'Brien", "space name", 'slash\\quote"']
    edges = [{"descendant_taxa": [label], "length": float(i + 1)} for i, label in enumerate(labels)]
    source = "[&R](" + ",".join("'" + label.replace("'", "''") + "':" + str(i + 1) for i, label in enumerate(labels)) + ")R;"
    oracle = expected(edges, labels[:1], labels[1:], 2)
    cases.append(("unicode-bom", document(source, labels[:1], labels[1:], 2, oracle), edges))
    for limit in [0, 4294967295]:
        row = rows["base-0-limit-2"]
        edges = facts["small-0-subset-15"]["edges"]
        oracle = expected(edges, ["A"], row["candidates"], limit)
        cases.append((f"limit-{limit}", document("[&R]" + row["newick"], ["A"], row["candidates"], limit, oracle), edges))
    valid = []
    for name, doc, edges in cases:
        path = output / f"{name}.plan.json"
        path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8-sig" if name == "unicode-bom" else "utf-8")
        loaded = json.loads(path.read_bytes().decode("utf-8-sig"))
        for target in ["js", "wasm-gc"]:
            response, _ = invoke(target, "review", name, path)
            valid.append({"case": name, "target": target, "input_sha256": sha(path),
                          **audit(response, loaded, edges)})

    exports = []
    demo_edges = [{"descendant_taxa": taxa, "length": length} for taxa, length in [
        (["A", "B"], 3.0), (["A"], 1.0), (["B"], 8.0),
        (["C", "D"], 6.0), (["C"], 4.0), (["D"], 5.0)]]
    for producer, reviewer in [("js", "wasm-gc"), ("wasm-gc", "js")]:
        doc, path = invoke(producer, "export", "export")
        response, _ = invoke(reviewer, "review", f"export-from-{producer}", path)
        exports.append({"producer": producer, "reviewer": reviewer, "saved_file": str(path),
                        "saved_sha256": sha(path), **audit(response, doc, demo_edges)})

    invalid = []
    seed = cases[0][1]
    for name, field, value, error in [
        ("claim", "expected_gain", 123.0, "claim_mismatch"),
        ("version", "schema", "phylo/future/v2", "unsupported_schema"),
        ("limit-overflow", "limit", "4294967296", "invalid_field"),
        ("limit-number", "limit", 2.5, "invalid_field"),
        ("tree-domain", "tree_newick", "(A:1,B:2);", "tree_error"),
    ]:
        doc = copy.deepcopy(seed)
        doc[field] = value
        path = output / f"invalid-{name}.plan.json"
        path.write_text(json.dumps(doc), encoding="utf-8")
        for target in ["js", "wasm-gc"]:
            response, _ = invoke(target, "review", f"invalid-{name}", path)
            assert response["ok"] is False and response["error"] == error
            invalid.append({"case": name, "target": target, "error": error})
    for target in ["js", "wasm-gc"]:
        response, _ = invoke(target, "review", "missing-env")
        assert response == {"ok": False, "error": "missing_document"}
        invalid.append({"case": "missing-env", "target": target, "error": "missing_document"})
    receipt = {"status": "passed", "source_fixtures": [
        {"path": str(p), "sha256": sha(p)} for p in [source_path, facts_path]],
        "method": "cached independent full edge facts; Fraction marginal scoring; actual persisted bytes and separate processes",
        "valid_reviews": valid, "cross_target_export_reviews": exports,
        "rejected_inputs": invalid, "invocations": invocations,
        "prior_generators_replayed": False, "network_or_third_party_runtime": False}
    (output / "consumer-readback.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "valid_reviews": len(valid),
                      "cross_target_reviews": len(exports), "rejected_inputs": len(invalid),
                      "processes": len(invocations)}))


if __name__ == "__main__":
    main()
