"""User request -> CLI create -> saved plan -> other-backend replay audit.

Reuses only the previous independent Fraction/edge-audit helpers, not their
main, scenarios or generators. Writes all artifacts outside the source tree.
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
from plan_document_review import audit, expected, bits

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = "phylo/faith-pd-greedy-request/v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def request(source, baseline, candidates, limit):
    return {"schema": SCHEMA, "tree_newick": source, "baseline_taxa": baseline,
            "candidate_taxa": candidates, "limit": str(limit)}


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

    def invoke(target, mode, name, path=None):
        env = os.environ.copy()
        env.pop("PHYLO_PLAN_REQUEST", None)
        env.pop("PHYLO_PLAN_DOCUMENT", None)
        if path:
            env["PHYLO_PLAN_REQUEST" if mode == "create" else "PHYLO_PLAN_DOCUMENT"] = path.read_bytes().decode("utf-8")
        command = [moon, "run", "cmd/plan_document", "--target", target, "--", mode]
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=60)
        stdout = output / f"{name}-{target}.stdout.json"
        stderr = output / f"{name}-{target}.stderr.log"
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        invocations.append({"target": target, "mode": mode, "command": command,
            "input": str(path) if path else None, "input_sha256": sha(path) if path else None,
            "exit_code": result.returncode, "stdout": str(stdout), "stdout_sha256": sha(stdout), "stderr": str(stderr)})
        (output / "commands.json").write_text(json.dumps(invocations, indent=2)+"\n", encoding="utf-8")
        assert result.returncode == 0, (command, result.stderr)
        return json.loads(result.stdout), stdout

    facts_path = ROOT / "testdata/diversity-golden.json"
    full = next(row for row in json.loads(facts_path.read_text())["fixtures"] if row["name"] == "real-all")
    real = request("[&R]" + full["newick"],
        ["Xeruca_formosensis", "Uca_princeps", "Petruca_panamensis"],
        ["Minuca_minax", "Leptuca_beebei", "Gelasimus_tetragonon", "Tubuca_rosea", "Paraleptuca_crassipes"], 2)
    labels = ["A space", "O'Brien", "𝛼_种", "龙"]
    edges = [{"descendant_taxa": [label], "length": value}
             for label, value in zip(labels, [2.0, 3.0, 7.0, 11.0])]
    source = "[&R]('A space':2,'O''Brien':3,'𝛼_种':7,'龙':11)R:37;"
    hand = request(source, ["A space"], ["𝛼_种", "A space", "龙", "O'Brien"], 2)
    cases = [("new-real-request", real, full["edges"]), ("quoted-supplementary-bom", hand, edges)]
    for limit in [0, 4294967295]:
        row = copy.deepcopy(hand)
        row["limit"] = str(limit)
        cases.append((f"new-request-limit-{limit}", row, edges))
    cases.append(("empty-request-sets", request(source, [], [], 4294967295), edges))
    passed = []
    oracle_rows = []
    for name, row, facts in cases:
        want = expected(facts, row["baseline_taxa"], row["candidate_taxa"], int(row["limit"]))
        if name == "quoted-supplementary-bom":
            assert [s["taxon"] for s in want["steps"]] == ["龙", "𝛼_种"] and want["gain"] == 18.0
        oracle_rows.append({"case": name, "request": row, "expected": want})
        path = output / f"{name}.request.json"
        if name == "new-real-request" and os.name == "nt":
            shell = shutil.which("pwsh") or shutil.which("powershell")
            assert shell, "PowerShell is required for the documented Windows request workflow"
            tree_path = output / "study.newick"
            tree_path.write_text(row["tree_newick"], encoding="utf-8")
            def ps_string(value):
                return "'" + value.replace("'", "''") + "'"
            script = output / "make-real-request.ps1"
            script.write_text("$ErrorActionPreference = 'Stop'\n$phyloRequest = @{\n"
                + "  schema = '" + SCHEMA + "'\n"
                + "  tree_newick = (Get-Content -LiteralPath " + ps_string(str(tree_path)) + " -Raw -Encoding utf8)\n"
                + "  baseline_taxa = @(" + ", ".join(map(ps_string, row["baseline_taxa"])) + ")\n"
                + "  candidate_taxa = @(" + ", ".join(map(ps_string, row["candidate_taxa"])) + ")\n"
                + "  limit = '2'\n}\n"
                + "$phyloRequest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "
                + ps_string(str(path)) + " -Encoding utf8\n", encoding="utf-8")
            generated = subprocess.run([shell, "-NoProfile", "-File", str(script)], capture_output=True, timeout=30)
            (output / "make-real-request.stdout.log").write_bytes(generated.stdout)
            (output / "make-real-request.stderr.log").write_bytes(generated.stderr)
            assert generated.returncode == 0 and json.loads(path.read_bytes().decode("utf-8-sig")) == row
        else:
            path.write_text(json.dumps(row, ensure_ascii=False, indent=2)+"\n",
                            encoding="utf-8-sig" if name == "quoted-supplementary-bom" else "utf-8")
        for producer, reviewer in [("js", "wasm-gc"), ("wasm-gc", "js")]:
            doc, saved = invoke(producer, "create", f"{name}-create", path)
            assert set(doc) == {"schema", "tree_newick", "baseline_taxa", "candidate_taxa", "limit",
                                "expected_added_taxa", "expected_gain", "expected_step_gains"}
            assert doc["schema"] == "phylo/faith-pd-greedy-plan/v1"
            assert doc["baseline_taxa"] == sorted(row["baseline_taxa"])
            assert doc["candidate_taxa"] == sorted(row["candidate_taxa"])
            assert doc["limit"] == row["limit"]
            assert doc["expected_added_taxa"] == [s["taxon"] for s in want["steps"]]
            assert bits(doc["expected_gain"]) == bits(want["gain"])
            response, _ = invoke(reviewer, "review", f"{name}-from-{producer}", saved)
            passed.append({"case": name, "producer": producer, "reviewer": reviewer,
                "request_sha256": sha(path), "saved_plan": str(saved), "saved_plan_sha256": sha(saved),
                **audit(response, doc, facts)})

    invalid = []
    def modified(field, value):
        row = copy.deepcopy(hand)
        row[field] = value
        return json.dumps(row)
    bad_cases = [
        ("json-syntax", "{", "invalid_json", None),
        ("object-required", "[]", "invalid_field", "request"),
        ("schema-version", modified("schema", "future"), "unsupported_schema", "future"),
        ("unknown-field", modified("extra", 1), "invalid_field", "extra"),
        ("tree-type", modified("tree_newick", 123), "invalid_field", "tree_newick"),
        ("taxon-item-type", modified("candidate_taxa", ["龙", 1]), "invalid_field", "candidate_taxa"),
        ("limit-number", modified("limit", 2.5), "invalid_field", "limit"),
        ("limit-negative", modified("limit", "-1"), "invalid_field", "limit"),
        ("limit-overflow", modified("limit", "4294967296"), "invalid_field", "limit"),
        ("root-required", modified("tree_newick", "('A space':2,'O''Brien':3,'𝛼_种':7,'龙':11);"), "tree_error", "RootedTreeRequired"),
        ("length-required", modified("tree_newick", "[&R]('A space':2,'O''Brien':3,'𝛼_种','龙':11);"), "tree_error", "MissingLength"),
        ("unknown-taxon", modified("candidate_taxa", ["missing"]), "tree_error", "UnknownTaxon"),
        ("duplicate-taxon", modified("candidate_taxa", ["龙", "龙"]), "tree_error", "DuplicateSelection"),
    ]
    for field in ["schema", "tree_newick", "baseline_taxa", "candidate_taxa", "limit"]:
        row = copy.deepcopy(hand)
        del row[field]
        bad_cases.append(("missing-"+field, json.dumps(row), "invalid_field", field))
    overflow = request("[&R](A:1e308,B:1e308);", [], ["A", "B"], 2)
    bad_cases.append(("domain-overflow", json.dumps(overflow), "tree_error", "NumericOverflow"))
    for name, text, code, detail in bad_cases:
        path = output / f"invalid-{name}.request.json"
        path.write_text(text, encoding="utf-8")
        for target in ["js", "wasm-gc"]:
            response, _ = invoke(target, "create", f"invalid-{name}", path)
            assert response["ok"] is False and response["error"] == code
            if detail:
                assert detail in response["detail"]
            invalid.append({"case": name, "target": target, "error": code})
    for target in ["js", "wasm-gc"]:
        response, _ = invoke(target, "create", "missing-request")
        assert response == {"ok": False, "error": "missing_request"}
        invalid.append({"case": "missing-request", "target": target, "error": "missing_request"})
    (output / "independent-expectations.json").write_text(json.dumps(oracle_rows, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    receipt = {"status": "passed", "source_fixture": str(facts_path), "source_fixture_sha256": sha(facts_path),
        "valid_cross_backend_chains": passed, "invalid_request_checks": invalid, "invocations": invocations,
        "old_adapter_main_scenarios_or_generators_replayed": False, "third_party_dependency": False,
        "method": "new requests; cached independent full-edge facts/Fraction; persisted request and produced plan bytes; cross-backend replay"}
    (output / "consumer-readback.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "new_requests": len(cases), "cross_backend_chains": len(passed),
                      "invalid_checks": len(invalid), "processes": len(invocations)}))


if __name__ == "__main__":
    main()
