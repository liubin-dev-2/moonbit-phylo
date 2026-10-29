# Necessary CI and evidence plan: selected-tree artifact and source lineage

Final `.github/workflows/check.yml` must pass all three existing required jobs:

- `Check, test and consumers (js)`.
- `Check, test and consumers (wasm-gc)`.
- `Independent NJ JSON consumers`.

Retain every existing gate, pinned SDK/dependency and old legal-input/default/
parser/error/scientific contract. No library or public interface changes.
The new necessary step is
`Validate public-package selected-tree export and source lineage on both targets`.
It runs `verification/prune_export_recipient.py` to build/check the separate
`examples/prune_export` public-import module for JS/Wasm-GC in an explicitly
bound product/receiver workspace. It consumes caller Newick plus a normal JSON
retain array and returns a selected artifact, exact original witness and source
edge lineage; root history remains separate from projected incoming edges.

Before-edit fixtures provide7 complete original/projected graphs, every source
mapping/None, each path/root history and complete literal Newick output, plus11
request/error scenarios. No pruning, path-summing or scientific reference oracle
is implemented/run to generate these expectations. Both backends make36 real
OS calls (14 successes/22 expected API errors), write14 actual exports and
record6 actual compiled artifacts. Verify every source/new node and optional
length bit/comment/rooting/label/parent, every witness/mapping/lineage/root
history record, request order and every exported byte. IDs reference their own
snapshots, not a later reparse; no product reparse is claimed.

Complete process regressions are appropriate for the new application. Locally
run info with unchanged-interface review, root/example fmt and new public strict
check/build/consumer gates once; do not add native mirror tests or rerun old
native/scientific/reference scenarios/generators. Required final CI retains the
unchanged full historical product gates. Preserve original failed attempts and
all stdout/stderr, numeric exits/statuses and runtime input bytes if failures
occur. Original input and actual exports stay immutable after execution.

Maintain distinct original raw SHA-256, indexed/worktree Git blob SHA-1,
tested/copied source, runtime input/output, local compiled binary identities and
remote branch/tree/job/step/upload metadata. Do not call cloud metadata local
binary equality. Final-head source ZIP/DEFLATED contains exactly final tracked
repository-relative paths with no outer folder, existing moon.mod metadata and
regular0644 content entries, excluding reports/builds/authentication material.
Read every member back once and record member identities against final source.

One normal own-author non-force commit/push; only exact-head required jobs and
new step green complete CI evidence. Accurate README/PROPOSAL/this plan and
REPORT/RESULT list completed scope, unsupported scope, actual artifacts/schema,
command exits, final SHA/CI URL/run/jobs and remainingRequiredWork. Old-evidence
preservation flags do not prove all history; do not reconstruct an old-history
inventory. Stop frozen for root independent ACCEPT. Do not self-count11, begin
R12 or claim the overall11-round goal/other-project targets complete.
