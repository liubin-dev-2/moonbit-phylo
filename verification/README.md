# Reference replay
The committed oracle_test.mbt literals were calculated by pinned external Python libraries, not by reading the MoonBit implementation. Golden data is testdata/golden.json. Product runtime has no Python dependency.

Reproduce offline from included CC0 source (Python 3.14 was used locally):
```
python -m venv verification/.venv
verification/.venv/Scripts/python -m pip install -r verification/requirements.txt
verification/.venv/Scripts/python verification/reference.py
moon test --target js
moon test --target wasm-gc
```
On Unix replace the Python executable path with verification/.venv/bin/python. Regeneration must preserve parsed golden contents; JSON formatting and generated MoonBit formatting may differ after moon fmt. The reference adapter quotes literal underscore labels to avoid mismatched parser defaults. Missing '?' is supplied as the state alphabet to DendroPy; Biopython is used for known-state Fitch only. Exhaustive scoring is applied only to the small trees (<=6 taxa), never relabeled as independent brute-force scoring on the 42-taxon sample.

The included source dataset is a Nexus container, converted by Biopython into the Newick profile. This conversion is verification tooling, not a claim that the MoonBit library implements Nexus. Cases use synthetic characters on the real tree; no biological trait reconstruction is claimed. Recorded local command failures and source identities are in the separate implementation-03 execution report.

Faith PD has a separate bounded adapter; running it does not regenerate the RF/Fitch corpus or download data:
```
verification/.venv/Scripts/python verification/diversity_reference.py
moon test --target js --filter 'faith PD*'
moon test --target wasm-gc --filter 'faith PD*'
```
It writes only `testdata/diversity-golden.json` and `diversity_oracle_test.mbt`. Biopython identifies each nonroot edge by descendant-tip intersection with the selected set; Fraction computes the independently rounded total. Tests audit the full contributing-edge multiset, including repeated unary descendant sets, shared ancestors, root-stem exclusion and zero-length edges. The 42-taxon input is reused without conversion or mutation. Selected test communities are synthetic, not the paper's observations.

Marginal Faith PD reuses the included independent branch facts with standard-library Python only:
```
python verification/diversity_gain_reference.py
moon test --target js --filter 'PD gain*'
moon test --target wasm-gc --filter 'PD gain*'
```
This writes only `testdata/diversity-gain-golden.json` and `diversity_gain_oracle_test.mbt`. An original edge contributes iff its descendant taxa intersect additions and do not intersect baseline. Exact Fraction sums establish gain without subtracting rounded PD values. The input fixture hash is recorded; no old generator is replayed, no data are downloaded, and no MoonBit implementation is read. The 271 cases include all 256 pairs of four-taxon subsets and preserve full newly contributing-edge multisets.

The stepwise selector also uses standard-library Python and the included independent branch facts:
```
python verification/diversity_greedy_reference.py
moon test --target js --filter 'PD greedy*'
moon test --target wasm-gc --filter 'PD greedy*'
```
It writes only `testdata/diversity-greedy-golden.json` and `diversity_greedy_oracle_test.mbt`. All candidate orders within each bounded pool are enumerated. The lexicographic sequence of (negative exact marginal gain, taxon) defines the expected deterministic choices; step edge multisets come from descendant-set intersections. Final unordered subsets are enumerated separately. This validates 106 cases/875 orders, not all possible 42-species selections or a universal constrained-optimization theorem. Existing input fixtures, data and generators are unchanged.

The bounded saved-plan workflow audit uses the existing pinned Biopython plus cached facts:
```
verification/.venv/Scripts/python verification/selection_workflow_reference.py
moon test --target js --filter 'selection audit*'
moon test --target wasm-gc --filter 'selection audit*'
moon run cmd/selection_resume --target js
```
It writes only `selection_workflow_audit_test.mbt` and `cmd/selection_resume/main.mbt`; optional `--receipt PATH` stores source hashes/counts for an execution report. Six seeds cover rotations/input permutations and product save/reload; 19 prefix positions cover saved continuation. Every rotated source first passes an independent branch-fact comparison. Labels are explicitly quoted so literal underscores remain literal. No old generator or corpus is replayed, no data are downloaded, and NodeId stability across different tree instances is not assumed.

The projection audit uses the existing pinned DendroPy and cached selection facts:
```
verification/.venv/Scripts/python verification/selection_projection_reference.py
moon test --target js --filter 'projection audit*'
moon test --target wasm-gc --filter 'projection audit*'
moon run cmd/selection_projection --target js
```
It writes only `selection_projection_cases_test.mbt` and `cmd/selection_projection/main.mbt`; the hand-audited graph-expansion helper is `selection_projection_audit_test.mbt`. Optional `--receipt PATH` stores independent projected facts and source hashes. Four cases compare suppression facts and expanded original edges; four reload the projected representation; a ninth preserves the documented Double precision boundary. The original tree and each projection/reload keep separate ID spaces. No old generator or source dataset is modified.

Portable plan-document checks exercise the new codec/replay and external-input consumer:
```
moon test --target js --filter 'plan document*' --deny-warn
moon test --target wasm-gc --filter 'plan document*' --deny-warn
python verification/plan_document_review.py --output ../plan-document-evidence
```
The toolchain must already be on PATH; the output directory must be outside the source tree. This standard-library-only adapter reads existing sealed greedy/full-edge fixtures, independently constructs six saved UTF-8 documents (including the 42-taxon research tree, BOM/Unicode, zero and maximum UInt limits), and runs separate CLI processes on both targets. It compares exact Fraction expectations, full edge multisets and all step/aggregate claims. It also saves each backend's exported bytes and reviews them on the other backend, then verifies structured errors for modified claims, bad versions/limits/domain input and missing input. Receipts include file hashes, commands, exit codes and stdout/stderr. It writes only to the chosen evidence directory; no old generator, dataset, source fixture or prior audit is replayed or changed. Domain failures are represented by `ok=false` JSON even though the example exits normally.

The custom-input create operation has a separate bounded consumer audit:
```
python verification/plan_request_review.py --output ../plan-request-evidence
```
It reuses only the previous independent Fraction/edge-audit helper functions; the previous adapter's main and old scenarios are not executed. Five new request files include a new synthetic selection on the existing CC0 tree, quoted/supplementary-Unicode labels and BOM, zero/max UInt, overlap and empty sets. On each target it creates an actual plan from those bytes, saves the output bytes and reviews them on the opposite target, checking the complete tree and contribution-edge facts. New request-boundary failures cover required/known/type/version/limit fields and unchanged domain validation. All writes and command/hash receipts stay in the chosen external output directory. No old tests, source fixtures, generators or distribution builds are replayed.

Verified checkpoint continuation has its own bounded operation audit:
```
python verification/plan_resume_review.py --output ../plan-resume-evidence
```
It independently authors six new checkpoint/count scenarios, including a new real-tree prefix, a hand total-versus-stage-gain example, extra0/max UInt, exhausted candidates and a zero-gain next taxon. It resumes each on both targets, saves the continuation and reviews it on the opposite backend, auditing complete tree/step edges, numeric bits, integer IDs and independently concatenated selection order. Refusal checks prove prior replay happens even for additional0; a valid finite prior can still produce a correctly rejected overflowing continuation. Only cached facts and prior independent helper functions are reused; no prior main/scenario/generator runs. Original checkpoint file hashes are checked unchanged, and all receipts stay in the external output directory.

Multi-round continuity and cumulative review use a separate focused consumer:
```
python verification/plan_chain_review.py --output ../plan-chain-evidence
```
Five new chains are reviewed on both targets. One is produced by actual create/resume/resume calls on a new real-tree request and bundled by the documented PowerShell workflow on Windows. Others test a normalized zero-middle chain, a single zero stage, three-stage rounding and individually finite stages with cumulative overflow. Cached full-edge/Fraction expectations check all source/cumulative edges, each stage choice/gain, final taxa and integer IDs. Failure cases include individually valid but disconnected baseline/pool/source documents, an invalid claim in a zero stage, bad outer/stage inputs and missing input. Chain validity is separate from cumulative numeric availability. Only prior independent helper functions are reused; old scenarios/generators/suites are not run. Input/stage file hashes remain unchanged and all receipts stay outside source.

The finite degenerate-graph audit uses existing artifacts without rebuilding:
```
python verification/plan_degenerate_review.py --output ../plan-degenerate-evidence
```
Node and moonrun must already be on PATH, and the normal JS/Wasm-GC artifacts must exist. Optional `--js-artifact PATH --wasm-artifact PATH` select sealed copies instead. The script executes those programs directly, from its external output directory, and records before/after artifact hashes. Three new literal-fact chains distinguish root-is-taxon/no edge, a unary study root with one real path and zero-length added branches. Two false zero-gain/root-stem claims are rejected on each backend. No runtime code, old scenario, generator, build or sum/left-fold assumption is involved; only a prior independent audit helper is reused.

An exact-ID JSON sharing chain has its own finite audit:
```
python verification/plan_identity_review.py --output ../plan-identity-evidence
```
Existing artifacts, Node, moonrun and PowerShell7 with EscapeHandling must be available; the same optional artifact-path flags select sealed copies. The new request contains two visually equivalent but exact-string-distinct IDs. It creates on JS, resumes on Wasm-GC, and uses actual PowerShell Default/EscapeNonAscii serialization. Both forms are reviewed on both backends. Literal code-point order and edge facts verify identities, tie order, stage gain2 and cumulative gain4/two edges. A wrong lookalike choice with unchanged gain and an externally NFC-collapsed duplicate request are rejected. Code-point/file/artifact receipts stay outside source; no normalization is added to the application and no old scenario, build or generator is replayed.

An availability-aware downstream consumer is audited separately:
```
python verification/plan_availability_review.py --output ../plan-availability-evidence
```
Existing artifacts/Node/moonrun/PowerShell7 and the optional artifact-path flags work as above. One new synthetic boundary chain has finite stages but an unrepresentable cumulative gain. Actual PowerShell gates on top-level chain validity, extracts the last v1 document and preserves it through JSON. A later resume must return gain3 with only the LaterSmall edge even though the baseline's absolute PD is too large. Single-plan review checks the finite stage; opposite-backend chain review checks the appended history remains valid with cumulative unavailable. Exact Fraction facts, numeric bits, complete source/step edges and integer IDs are checked. Six direct artifact executions and one host consumer process are recorded; no rebuild, old scenario/generator or stage-Double-sum oracle runs.

A changed candidate pool is audited as a separate scenario:
```
python verification/plan_pool_fork_review.py --output ../plan-pool-fork-evidence
```
The same installed tools, existing artifacts and optional artifact-path flags apply. One new seven-edge synthetic study creates a prefix and reviews it on the other backend. Resume keeps the old pool and chooses Maple6. Actual PowerShell gates on the single-plan review, takes its verified selected taxa as baseline and writes a new request containing Birch; create chooses Birch8. Independent Fraction/full-edge audits validate the original two-stage chain (origin Oak, cumulative18) and the separate one-stage fork (origin Oak/Pine, cumulative8). Mixing the two valid plans is rejected specifically for candidate_taxa at stage1. The unequal origins are recorded rather than used for ranking. Seven frozen program executions and one PowerShell process record all file/artifact identities and integer IDs; no runtime change, rebuild, old main/scenario/generator or old suite runs.

Field-aware diagnostic routing has a real consumer audit:
```
python verification/plan_error_field_review.py --output ../plan-error-field-evidence
```
Build the current plan_document executable for JS/Wasm-GC first; existing Node/moonrun and PowerShell7 are required. The same optional artifact-path flags select saved copies, and each run needs a fresh external output directory. Invalid numeric limit requests run on both backends, followed by a corrected create/resume pair. Direct and nested changed-claim errors expose expected_gain while keeping the original classification/detail/index. Actual PowerShell maps field values to known request/claim controls without reading detail and falls back for an ambiguous domain error with no field. An untampered chain is independently checked against all six source-edge facts, exact Fraction expectations, integer IDs and cumulative18/three edges. Eight application calls and one host process record immutable input/output/artifact identities. No old scenario/generator/main or compiler runs inside this adapter, and no claim is silently repaired.
