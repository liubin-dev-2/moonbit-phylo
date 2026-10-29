# Necessary CI and evidence plan: stable ladderized export

The final commit must pass the existing `.github/workflows/check.yml` jobs:

- `Check, test and consumers (js)`.
- `Check, test and consumers (wasm-gc)`.
- `Independent NJ JSON consumers`.

Retain all existing native/public/reference/file/route/clade/Fitch/rename gates
and pinned SDK/dependencies. The only public addition is
`PhyloTree::ladderize(reverse?:Bool=false)->PhyloTree`; no old interface is
removed, no parser/error/scientific/default contract is changed. New native
groups verify whole-node preservation/stable ordering, degenerate/deep/repeat
behavior, and fresh private arena/child/comment/tree-comment storage. Do not
regenerate scientific references or count retries as another meaningful round.

The new necessary step is
`Validate public-package stable ladderized export on both targets`.
It runs `verification/ladderize_recipient.py` with Python stdlib only and builds
`examples/ladderize_export`, a separate public-import module in an explicitly
bound product/receiver workspace. Before-edit literal fixtures give complete
original graphs, every expected sibling list and every visible terminal row;
no copy of the new counting/sorting method is the expected-value oracle.
Eight success/six error cases per target produce28 real OS calls,16 actual
UTF-8 Newick exports and6 local compiled artifacts. Validate every original,
ordered and actual same-process reparse node, all row IDs/names/order, optional
length bits, rooting and comments. Reparse IDs belong to that new parse.

Preserve original input files, exported bytes and all stdout/stderr, with each
numeric return code, success/expected-error status, executable and byte hashes.
The bridge saves exports; environment text input retains host limits. No native
file host, new persistent format, layout/renderer or external adoption claim.
Local verification runs only the new native/consumer tests and strict
check/info/fmt/interface gates; old scientific/reference scenarios are not rerun
locally. Required final CI retains its full existing gates.

Distinguish original Git blob SHA-1, raw worktree SHA-256, tested/copied source,
actual compiled bytes, process inputs/outputs and remote job/upload metadata.
The final-head source deliverable is ZIP/DEFLATED with exactly all final tracked
repository-relative paths, no enclosing directory, existing moon.mod metadata
and content entries0644. Read back every member once against final source
hashes; exclude reports/build caches/credentials/private auth paths. The initial
source ZIP or remote metadata is not a substitute for current source bytes or
cloud compiled payload equality.

Only exact final-head necessary jobs and new-step success complete CI evidence.
Preserve all initial failures. Seal accurate README/PROPOSAL/this plan plus
REPORT/RESULT listing final SHA, CI URL/run/jobs/new step, command exits, actual
artifact paths/schema, completed/unsupported scope and remainingRequiredWork.
Root alone ACCEPTs/counts the finite round; stop without starting R11 or
claiming the11-round goal complete. Do not turn old-evidence preservation flags
into proof of all history or rescan old materials to construct such proof.
