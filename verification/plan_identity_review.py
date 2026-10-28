"""One new exact-ID create/resume/raw-and-escaped sharing audit.

Uses existing compiled artifacts and literal edge facts. No build, old scenario,
Unicode normalization in the application, or sum-as-Double-fold comparison.
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
import unicodedata

sys.dont_write_bytecode = True
from plan_chain_review import audit

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
    assert node and moonrun and pwsh, "installed Node, moonrun and PowerShell7 must be on PATH"
    artifacts = {"js": args.js_artifact.resolve(), "wasm-gc": args.wasm_artifact.resolve()}
    identities = [{"target": target, "path": str(path), "sha256": sha(path)} for target, path in artifacts.items()]
    commands, inputs = [], []
    def invoke(target, mode, name, path, count=None):
        env = os.environ.copy()
        for key in ["PHYLO_PLAN_REQUEST", "PHYLO_PLAN_DOCUMENT", "PHYLO_PLAN_ADDITIONAL_LIMIT", "PHYLO_PLAN_CHAIN"]:
            env.pop(key, None)
        key = "PHYLO_PLAN_REQUEST" if mode == "create" else "PHYLO_PLAN_DOCUMENT" if mode == "resume" else "PHYLO_PLAN_CHAIN"
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
        return json.loads(result.stdout), stdout

    composed, decomposed = "Caf\u00e9", "Cafe\u0301"
    assert composed != decomposed and unicodedata.normalize("NFC", decomposed) == composed
    assert ord(decomposed[3]) == 0x65 < ord(composed[3]) == 0xE9
    source = "[&R]('"+composed+"':2,'"+decomposed+"':2,Control:5)Study:500;"
    request = {"schema": "phylo/faith-pd-greedy-request/v1", "tree_newick": source,
               "baseline_taxa": ["Control"], "candidate_taxa": [composed, decomposed], "limit": "1"}
    request_path = output / "exact-identity.request.json"
    request_path.write_text(json.dumps(request, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    first, first_path = invoke("js", "create", "exact-identity-first", request_path)
    assert first["expected_added_taxa"] == [decomposed] and first["expected_gain"] == 2
    assert first["candidate_taxa"] == [decomposed, composed] and first["baseline_taxa"] == ["Control"]
    second, second_path = invoke("wasm-gc", "resume", "exact-identity-second", first_path, 1)
    assert second["expected_added_taxa"] == [composed] and second["expected_gain"] == 2
    assert second["baseline_taxa"] == sorted([decomposed, "Control"])
    documents = [first, second]
    raw_path, escaped_path = output / "identity-raw.chain.json", output / "identity-escaped.chain.json"
    def ps(value):
        return "'" + str(value).replace("'", "''") + "'"
    script = output / "share-identity-chain.ps1"
    script.write_text("$ErrorActionPreference = 'Stop'\n$phyloChain = @(\n"+
        "\n".join("  (Get-Content -LiteralPath "+ps(p)+" -Raw -Encoding utf8 | ConvertFrom-Json)" for p in [first_path, second_path])+
        "\n)\nConvertTo-Json -InputObject $phyloChain -Depth 8 -EscapeHandling Default | Set-Content -LiteralPath "+ps(raw_path)+" -Encoding utf8\n"
        +"ConvertTo-Json -InputObject $phyloChain -Depth 8 -EscapeHandling EscapeNonAscii | Set-Content -LiteralPath "+ps(escaped_path)+" -Encoding utf8\n",
        encoding="utf-8")
    serializer_command = [pwsh, "-NoProfile", "-File", str(script)]
    serialized = subprocess.run(serializer_command, capture_output=True, timeout=30)
    (output / "serializer.stdout.log").write_bytes(serialized.stdout)
    (output / "serializer.stderr.log").write_bytes(serialized.stderr)
    assert serialized.returncode == 0, serialized.stderr
    raw_text = raw_path.read_bytes().decode("utf-8-sig")
    escaped_text = escaped_path.read_bytes().decode("utf-8-sig")
    assert composed in raw_text and decomposed in raw_text
    assert escaped_text.isascii() and "\\u00e9" in escaped_text.lower() and "\\u0301" in escaped_text.lower()
    assert raw_path.read_bytes() != escaped_path.read_bytes()
    assert json.loads(raw_text) == json.loads(escaped_text) == documents
    for path in [request_path, first_path, second_path, raw_path, escaped_path]:
        inputs.append({"path": str(path), "sha256": sha(path)})
    edges = [{"descendant_taxa": [label], "length": length}
             for label, length in [(composed, 2.0), (decomposed, 2.0), ("Control", 5.0)]]
    valid = []
    for encoding, path in [("raw-UTF8", raw_path), ("escaped-ASCII", escaped_path)]:
        for target in ["js", "wasm-gc"]:
            response, _ = invoke(target, "review-chain", encoding, path)
            result = audit(response, documents, edges)
            assert response["stage_added_taxa"] == [[decomposed], [composed]]
            assert response["cumulative"]["report"]["added_taxa"] == [decomposed, composed]
            assert response["cumulative"]["report"]["gain"] == 4 and len(response["cumulative"]["report"]["edge_ids"]) == 2
            valid.append({"encoding": encoding, "target": target, "input_sha256": sha(path), **result})

    wrong_identity = copy.deepcopy(documents)
    wrong_identity[0]["expected_added_taxa"] = [composed]
    wrong_path = output / "wrong-lookalike-choice.chain.json"
    wrong_path.write_text(json.dumps(wrong_identity, ensure_ascii=False), encoding="utf-8")
    normalized = copy.deepcopy(request)
    normalized["candidate_taxa"] = [unicodedata.normalize("NFC", x) for x in request["candidate_taxa"]]
    assert normalized["candidate_taxa"] == [composed, composed]
    normalized_path = output / "externally-normalized-duplicate.request.json"
    normalized_path.write_text(json.dumps(normalized, ensure_ascii=False), encoding="utf-8")
    rejected = []
    for target in ["js", "wasm-gc"]:
        response, _ = invoke(target, "review-chain", "wrong-lookalike-choice", wrong_path)
        assert response["ok"] is False and response["error"] == "stage_failed" and response["stage_index"] == 0
        assert response["cause"]["error"] == "claim_mismatch" and "expected_added_taxa" in response["cause"]["detail"]
        rejected.append({"case": "wrong-lookalike-choice-same-gain", "target": target, "cause": "claim_mismatch"})
        response, _ = invoke(target, "create", "externally-normalized-duplicate", normalized_path)
        assert response["ok"] is False and response["error"] == "tree_error" and "DuplicateSelection" in response["detail"]
        rejected.append({"case": "externally-normalized-candidates", "target": target, "cause": "DuplicateSelection"})
    assert all(sha(Path(row["path"])) == row["sha256"] for row in inputs)
    assert all(sha(Path(row["path"])) == row["sha256"] for row in identities)
    ledger = [{"role": role, "id": label, "code_points": [f"U+{ord(c):04X}" for c in label]}
              for role, label in [("first chosen decomposed ID", decomposed), ("second chosen composed ID", composed)]]
    (output / "taxon-code-points.json").write_text(json.dumps(ledger, ensure_ascii=True, indent=2)+"\n", encoding="utf-8")
    receipt = {"status": "passed", "valid_encoding_reviews": valid, "rejections": rejected, "commands": commands,
        "artifacts": identities, "inputs_unchanged": inputs, "identity_ledger": ledger,
        "serializer": {"command": serializer_command, "exit_code": serialized.returncode, "script": str(script),
            "script_sha256": sha(script), "raw_sha256": sha(raw_path), "escaped_sha256": sha(escaped_path),
            "decoded_objects_equal": True, "file_bytes_differ": True},
        "build_or_compiler_invocations": 0, "new_runtime_feature_or_repair": False,
        "old_mains_scenarios_generators_replayed": False, "application_normalization_added": False,
        "reference": "literal distinct BMP ID/code-unit order and three nonroot edges; existing independent chain audit helper only"}
    (output / "consumer-readback.json").write_text(json.dumps(receipt, ensure_ascii=True, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "producer_steps": 2, "encoding_reviews": len(valid),
                      "rejections": len(rejected), "frozen_artifact_executions": len(commands), "builds": 0}))


if __name__ == "__main__":
    main()
