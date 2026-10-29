# Necessary CI and evidence plan: taxon naming handoff

The final commit must pass the existing `.github/workflows/check.yml` jobs:

- `Check, test and consumers (js)`.
- `Check, test and consumers (wasm-gc)`.
- `Independent NJ JSON consumers`.

Retain all old native/public/reference/file/route/clade/Fitch gates and their
pinned SDK/dependencies. The new library API is additive; old source/interfaces
and legal-input/default/error/mathematical contracts are retained. Native gates
include three focused black-box rename groups: simultaneous whole-graph copy,
atomic source/empty/collision validation, and exact Unicode/quoted Newick handoff.
Do not regenerate scientific references or count a retry as another round.

The new necessary step is
`Validate two-process public-package taxon rename handoff on both targets`.
It runs `verification/taxon_rename_recipient.py` with Python stdlib only, building
the public-import emitter and distinct receiver for JS/Wasm-GC in an explicitly
bound product/receiver workspace. Original graphs, all expected target labels
and ordered correspondence facts are hand-fixed before implementation; complete
results and required API errors must be consumed in real new processes.

For each successful emitter, save `renamed_newick` as raw UTF-8 `.newick` bytes,
read those bytes without newline normalization and feed only that tree to a new
receiver process. Compare every node/edge relationship, label, optional length,
comment/rooting and the exact canonical re-export. Reparse IDs belong to that
parse. Retain original inputs, exports, stdout and stderr; record numerical
return codes, pass/expected-error status, executable hash and byte hashes.
The bridge performs file I/O; the MoonBit examples keep existing text transport.

Local evidence distinguishes original Git blob SHA-1, raw worktree SHA-256,
copied/tested source SHA-256, actual compiled artifacts and complete raw output
bytes. Source deliverable format is ZIP: exactly the final Git-tracked files,
with repository-relative member paths and no enclosing directory. `moon.mod`
is the unchanged module metadata; this package adds no scientific/input schema.
Read back every ZIP member once against the final source manifest. Exclude
reports, build caches, credentials, local authentication paths and private data
from the public source package. Do not substitute the initial source ZIP.

Only actual final-head job/step success is completion evidence. A saved workflow,
manifest or local pass is not remote CI proof; metadata is not remote compiled
binary payload equality. Preserve failed original logs and incomplete states.
Seal README/PROPOSAL, this plan and a result identifying the final commit, CI
URL/run ID/jobs/new step, actual exits, artifact paths/schema, completed scope,
unsupported scope and remaining required work. Root alone accepts/counts the
finite round; this self-authored real receiving workflow is not external adoption.
