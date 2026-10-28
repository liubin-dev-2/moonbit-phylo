"""Fixed Biopython goldens and real JS/Wasm-GC JSON consumer acceptance.

Use PYTHONPATH for an isolated reference installation. --generate writes only
the two named fixtures; normal validation never updates expected results.
"""
from __future__ import annotations

import argparse
import hashlib
import inspect
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
from fractions import Fraction

import Bio
import numpy
from Bio.Phylo.TreeConstruction import DistanceMatrix, DistanceTreeConstructor

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "verification/nj_cases.json"
SOURCE_SHA = "4ae4a1bdadcdc5162882d470bc64e8106091e3092e64c6ac81477f28b17b42f7"


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def metadata():
    source_sha = hashlib.sha256(inspect.getsource(DistanceTreeConstructor.nj).encode()).hexdigest()
    assert Bio.__version__ == "1.88", Bio.__version__
    assert numpy.__version__ == "2.5.4", numpy.__version__
    assert source_sha == SOURCE_SHA, source_sha
    return {"biopython": Bio.__version__, "numpy": numpy.__version__, "nj_source_sha256": source_sha}


def lexical(s):
    return s.encode("utf-16-be", errors="surrogatepass")


def sort_names(names):
    return sorted(names, key=lexical)


def split_key(side, taxa):
    left = tuple(sort_names(side))
    right = tuple(sort_names(set(taxa) - set(side)))
    return min((left, right), key=lambda x: (len(x), tuple(map(lexical, x))))


def branch_facts(tree, taxa):
    facts = {}
    for clade in tree.find_clades():
        if clade is tree.root:
            continue
        key = split_key([leaf.name for leaf in clade.get_terminals()], taxa)
        facts[key] = facts.get(key, 0.0) + clade.branch_length
    return [{"taxa": list(k), "length": v} for k, v in sorted(facts.items())]


def newick(clade):
    if clade.clades:
        body = "(" + ",".join(newick(child) for child in clade.clades) + ")"
    else:
        body = "'" + clade.name.replace("'", "''") + "'"
    return body + (":" + format(clade.branch_length, ".17g") if clade.branch_length is not None else "")


def source_cases():
    taxa = list("ABCDE")
    additive = [[0., 5., 20., 29., 30.], [5., 0., 21., 30., 31.],
                [20., 21., 0., 19., 20.], [29., 30., 19., 0., 13.], [30., 31., 20., 13., 0.]]
    noisy = [row[:] for row in additive]
    for i, j, delta in [(0, 2, .5), (1, 4, -.25), (2, 3, .375)]:
        noisy[i][j] += delta
        noisy[j][i] += delta
    fractional = [[0. if i == j else 10. for j in range(5)] for i in range(5)]
    fractional[0][1] = fractional[1][0] = 2.
    fractional[0][2] = fractional[2][0] = 11.
    fractional[3][4] = fractional[4][3] = 8.
    return [("five_additive", taxa, additive), ("five_noisy", taxa, noisy),
            ("five_fractional", taxa, fractional)]


def generate():
    cases = []
    for name, taxa, values in source_cases():
        n = len(taxa)
        rows = [sum(map(Fraction, row)) for row in values]
        qs = [(Fraction(values[i][j]) - (rows[i] + rows[j]) / (n - 2), i, j)
              for i in range(n) for j in range(i + 1, n)]
        qs.sort()
        assert qs[0][0] < qs[1][0], "initial informative minimum must be unique"
        # For these five-tip fixtures, examine the remaining four-cluster Qs
        # with exact Fractions. Only complementary descriptions of ONE split
        # may tie. This rejects fixtures with genuine topology ambiguity.
        _, mi, mj = qs[0]
        keep = [i for i in range(n) if i not in (mi, mj)]
        groups = [[taxa[i]] for i in keep] + [[taxa[mi], taxa[mj]]]
        reduced = [(Fraction(values[mi][k]) + Fraction(values[mj][k]) - Fraction(values[mi][mj])) / 2 for k in keep]
        d4 = [[Fraction(values[i][j]) for j in keep] + [reduced[r]] for r, i in enumerate(keep)]
        d4.append(reduced + [Fraction(0)])
        sums4 = [sum(row) for row in d4]
        q4 = [(d4[i][j] - (sums4[i] + sums4[j]) / 2, split_key(groups[i] + groups[j], taxa))
              for i in range(4) for j in range(i + 1, 4)]
        minimum4 = min(q for q, _ in q4)
        assert len({split for q, split in q4 if q == minimum4}) == 1, "ambiguous four-cluster topology"
        # Inputs are independently authored, symmetric with an exact zero
        # diagonal BEFORE Biopython's DistanceMatrix can normalize the diagonal.
        assert all(values[i][i] == 0 and all(math.isfinite(x) and x >= 0 for x in values[i]) for i in range(n))
        assert all(values[i][j] == values[j][i] for i in range(n) for j in range(n))
        dm = DistanceMatrix(taxa, [values[i][:i + 1] for i in range(n)])
        tree = DistanceTreeConstructor().nj(dm)
        assert tree.rooted is False
        fitted = [[tree.distance(a, b) for b in taxa] for a in taxa]
        cases.append({"name": name, "matrix": {"taxa": taxa, "values": values},
                      "first_minimum": [taxa[qs[0][1]], taxa[qs[0][2]]],
                      "first_minimum_gap_exact": str(qs[1][0] - qs[0][0]),
                      "remaining_four_cluster_minimum_split": list(next(split for q, split in q4 if q == minimum4)),
                      "tie_note": "unique initial informative pair; later four-tip complementary Q ties are inherent",
                      "newick": "[&U]" + newick(tree.root) + ";",
                      "branches": branch_facts(tree, taxa), "fitted": fitted})
    fixture = {"reference": metadata(), "absolute_tolerance": 1e-10, "relative_tolerance": 1e-12, "cases": cases}
    FIXTURE.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    blocks = ["// Generated by verification/nj_reference.py --generate from fixed Biopython 1.88.\n"]
    for case in cases:
        matrix = json.dumps(case["matrix"], ensure_ascii=False, separators=(",", ":"))
        blocks.append('///|\ntest "Biopython 1.88 ' + case["name"] + ' paths and unrooted split" {\n'
                      '  let report = @nj.from_json(' + json.dumps(matrix, ensure_ascii=False) + ').unwrap()\n'
                      '  let reference = @phylo.PhyloTree::from_newick(' + json.dumps(case["newick"]) + ').unwrap()\n'
                      '  assert_eq(report.tree.rf_distance_unrooted(reference).unwrap().distance, 0)\n'
                      '  let expected : Array[Array[Double]] = ' + json.dumps(case["fitted"]) + '\n'
                      '  for i = 0; i < 5; i = i + 1 {\n'
                      '    for j = i + 1; j < 5; j = j + 1 {\n'
                      '      near(report.fitted.values[i][j], expected[i][j])\n'
                      '    }\n  }\n}\n')
    (ROOT / "nj/reference_cases_test.mbt").write_text("\n".join(blocks), encoding="utf-8")
    print(json.dumps({"generated": len(cases), "reference": fixture["reference"]}))


def near(actual, expected):
    assert math.isfinite(actual), actual
    assert abs(actual - expected) <= 1e-10 + 1e-12 * abs(expected), (actual, expected)


def payload_branches(payload):
    nodes = {node["id"]: node for node in payload["nodes"]}
    taxa = payload["fitted"]["taxa"]
    facts = {}

    def descendants(index):
        node = nodes[index]
        if not node["children"]:
            return [node["label"]]
        return [name for child in node["children"] for name in descendants(child)]

    for node in nodes.values():
        if "parent" not in node:
            continue
        length = node["length"]
        assert math.isfinite(length) and length >= 0
        key = split_key(descendants(node["id"]), taxa)
        facts[key] = facts.get(key, 0.0) + length
    return facts


def reject_constants(value):
    raise AssertionError("nonfinite JSON constant: " + value)


def validate(args):
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert fixture["reference"] == metadata()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    artifacts = Path(args.artifact_dir)
    runs = []
    cases = fixture["cases"] + [
        {"name": "analytic_additive4", "matrix": {"taxa": list("ABCD"), "values": [[0,3,9,10],[3,0,10,11],[9,10,0,7],[10,11,7,0]]},
         "newick": "[&U]((A:1,B:2):5,C:3,D:4);"},
        {"name": "analytic_ring", "matrix": {"taxa": list("ABCD"), "values": [[0,1,2,1],[1,0,1,2],[2,1,0,1],[1,2,1,0]]},
         "newick": "[&U]((A:0.5,B:0.5):0.5,C:0.5,D:0.5);"},
        {"name": "quoted_unicode2", "matrix": {"taxa": ["样本🙂", "A_B'"], "values": [[0,6],[6,0]]}},
        {"name": "tiny2", "matrix": {"taxa": ["A", "B"], "values": [[0,5e-324],[5e-324,0]]}},
        {"name": "tiny3_rounding", "matrix": {"taxa": list("ABC"), "values": [[0,5e-324,5e-324],[5e-324,0,5e-324],[5e-324,5e-324,0]]}},
        {"name": "negative3", "matrix": {"taxa": list("ABC"), "values": [[0,1,1],[1,0,3],[1,3,0]]}, "error": "negative_limb"},
        {"name": "negative4_merge", "matrix": {"taxa": list("ABCD"), "values": [[0,1,1,1],[1,0,3,3],[1,3,0,2],[1,3,2,0]]}, "error": "negative_limb"},
        {"name": "huge4", "matrix": {"taxa": list("ABCD"), "values": [[0 if i==j else 1e308 for j in range(4)] for i in range(4)]},
         "newick": "[&U]((A:5e307,B:5e307):0,C:5e307,D:5e307);"},
        {"name": "duplicate", "matrix": {"taxa": ["A","A"], "values": [[0,1],[1,0]]}, "error": "duplicate_taxon"},
        {"name": "diagonal", "matrix": {"taxa": ["A","B"], "values": [[1,1],[1,0]]}, "error": "nonzero_diagonal"},
        {"name": "asymmetric", "matrix": {"taxa": ["A","B"], "values": [[0,1],[2,0]]}, "error": "asymmetric"},
        {"name": "shape", "matrix": {"taxa": ["A","B"], "values": [[0],[1,0]]}, "error": "invalid_shape"},
        {"name": "negative_distance", "matrix": {"taxa": ["A","B"], "values": [[0,-1],[-1,0]]}, "error": "negative_distance"},
        {"name": "numeric_json_overflow", "text": '{"taxa":["A","B"],"values":[[0,1e999],[1e999,0]]}', "error": ["invalid_json", "non_finite"]},
        {"name": "nan_json", "text": '{"taxa":["A","B"],"values":[[0,NaN],[NaN,0]]}', "error": "invalid_json"},
        {"name": "missing_matrix", "error": "missing_matrix"},
    ]
    for target in ["js", "wasm-gc"]:
        artifact = artifacts / target / "debug/build/cmd/nj_matrix" / ("nj_matrix.js" if target == "js" else "nj_matrix.wasm")
        runner = shutil.which("node") if target == "js" else args.moonrun
        assert artifact.is_file() and runner
        for case in cases:
            env = os.environ.copy()
            env.pop("PHYLO_NJ_MATRIX", None)
            env.pop("PHYLO_NJ_REFERENCE", None)
            if "matrix" in case or "text" in case:
                env["PHYLO_NJ_MATRIX"] = case.get("text", json.dumps(case.get("matrix"), ensure_ascii=False, separators=(",", ":"), allow_nan=False))
            if "newick" in case:
                env["PHYLO_NJ_REFERENCE"] = case["newick"]
            result = subprocess.run([runner, str(artifact)], env=env, capture_output=True, timeout=30)
            stem = target + "-" + case["name"]
            (output / (stem + ".stdout.json")).write_bytes(result.stdout)
            (output / (stem + ".stderr.log")).write_bytes(result.stderr)
            assert result.returncode == 0, (stem, result.returncode, result.stderr)
            payload = json.loads(result.stdout, parse_constant=reject_constants)
            if "error" in case:
                accepted = case["error"] if isinstance(case["error"], list) else [case["error"]]
                assert payload["ok"] is False and payload["error"] in accepted, (stem, payload)
                assert "newick" not in payload
                if case["name"] in ("negative3", "negative4_merge"):
                    assert payload["taxa"] == ["A"] and payload["length"] == -.5
            else:
                assert payload["ok"] is True and payload["rooting"] == "unrooted"
                assert payload["newick"].startswith("[&U]")
                assert payload["input"]["taxa"] == sort_names(case["matrix"]["taxa"])
                if "newick" in case:
                    assert payload["comparison"]["distance"] == 0
                if "branches" in case:
                    actual = payload_branches(payload)
                    expected = {tuple(edge["taxa"]): edge["length"] for edge in case["branches"]}
                    assert actual.keys() == expected.keys(), (stem, actual, expected)
                    for key in expected:
                        near(actual[key], expected[key])
                    for i in range(5):
                        for j in range(5):
                            near(payload["fitted"]["values"][i][j], case["fitted"][i][j])
                pairs = [payload["residuals"][i][j] for i in range(len(payload["input"]["taxa"])) for j in range(i + 1, len(payload["input"]["taxa"]))]
                for i in range(len(payload["input"]["taxa"])):
                    for j in range(len(payload["input"]["taxa"])):
                        near(payload["residuals"][i][j], payload["fitted"]["values"][i][j] - payload["input"]["values"][i][j])
                maximum = max(map(abs, pairs))
                rms = maximum * math.sqrt(math.fsum((r / maximum)**2 for r in pairs) / len(pairs)) if maximum else 0.
                near(payload["max_abs_residual"], maximum)
                near(payload["rms_residual"], rms)
                if case["name"] == "analytic_additive4":
                    assert payload["fitted"]["values"] == case["matrix"]["values"] and maximum == 0
                if case["name"] == "analytic_ring":
                    assert pairs == [0., -.5, .5, .5, -.5, 0.]
                    assert maximum == .5
                    near(rms, math.sqrt(1/6))
                if case["name"] == "tiny2":
                    assert payload["fitted"]["values"][0][1] == 5e-324 and maximum == 0
                if case["name"] == "tiny3_rounding":
                    assert maximum == 5e-324 and payload["max_abs_residual"] == 5e-324 and payload["rms_residual"] == 5e-324
                if case["name"] == "quoted_unicode2":
                    assert payload["fitted"]["taxa"] == ["A_B'", "样本🙂"] and payload["fitted"]["values"][0][1] == 6
            runs.append({"target": target, "case": case["name"], "ok": True, "artifact_sha256": digest(artifact)})
    receipt = {"status": "passed", "reference": metadata(), "fixture_sha256": digest(FIXTURE),
               "runs": runs, "count": len(runs), "scope": "new NJ JSON consumer; normalized unrooted branches/splits/paths and declared error policies"}
    (output / "RESULT.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "consumer_runs": len(runs), "output": str(output)}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--generate", action="store_true")
    parser.add_argument("--artifact-dir")
    parser.add_argument("--moonrun")
    parser.add_argument("--output")
    args = parser.parse_args()
    if args.generate:
        generate()
    else:
        assert args.artifact_dir and args.moonrun and args.output
        validate(args)


if __name__ == "__main__":
    main()
