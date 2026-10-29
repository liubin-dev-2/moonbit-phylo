# Supported CI toolchain and evidence

The [MoonBit checks workflow](https://github.com/liubin-dev-2/moonbit-phylo/actions/workflows/check.yml)
runs on ordinary Ubuntu 24.04 GitHub-hosted runners. Both `js` and `wasm-gc`
must pass formatting, interface review, strict check, build, all native tests and
the existing public consumers. The independent NJ job also executes both built
consumers against the fixed Biopython goldens and hand-tree/Fraction range
expectations, including tiny mixed-scale branches and genuine output overflow.
Every case checks its declared success/error expectation.

The same required NJ job runs `verification/nj_file.py` in real Node processes:
the JS-only file selector reads a 128-taxon UTF-8 JSON file, independently checks
253 edge lengths, 125 internal splits and all 16,384 ordered paths against a
specified weighted tree, and checks encoding/JSON/file errors and unchanged
input hashes. Small environment controls still run on both targets; Wasm-GC
must explicitly reject file mode. The new suite uses Python stdlib only and
does not regenerate the existing reference or range fixtures.

That job also builds and executes `cmd/patristic_path` on JS and Wasm-GC.
`verification/patristic_path.py` checks complete ordered node/edge witnesses
against authored undirected graphs and BFS/Fraction expectations, including
actual export/reparse, Unicode identity, zero/subnormal/one-round sums, overflow
and existing length-validation errors. The ordinary check jobs record the new
consumer's compiled hash and run the new public-API native tests. No previous
reference generator is rerun to create expected results.

The required job also executes `verification/path_file.py`: a fresh Node process
reads original Newick bytes using the path-only selector, with independent full
graph/path, comments/rooting/stem and input-hash checks. It covers literal file
paths, strict UTF-8/BOM and parser/domain/selection errors. Existing JS/Wasm-GC
text controls remain; Wasm-GC file mode must explicitly reject the request.
This is a transport check, without regenerating scientific fixtures or adding
a new parser, format or numerical algorithm.

The original-tree RF recipient is separately built and executed on both targets
by `verification/rf_recipient.py` in that required job. Literal hand-enumerated
full clade/split reports distinguish rooted/unrooted dispatch, reverse inputs,
zero edges and unresolved trees; structured selection/parse/root/leaf-set errors
and exactly one JSON response are checked. The core RF algorithm and old
scientific reference fixtures are unchanged.

`verification/authored_route_recipient.py` creates a separate public-import
highlighter module/workspace and executes it on JS and Wasm-GC in the required
job. Literal hand roles are mapped through original pre-query NodeRecord IDs,
checking ordered nodes/child-edges, highlighting, missing/zero lengths, markers,
stem/subdivision behavior, errors and new result ownership. The ordinary native
gates retain weighted path regressions after the narrowly shared geometry;
numeric algorithms and previous reference generators remain unchanged.

`verification/clade_recipient.py` builds a separate public-import clade review
module in a clean copied-source workspace, then runs both targets in that same
required job. Pre-implementation hand facts specify the MRCA, complete clade,
intruders and all terminal classifications, including root-dependent outcomes,
unary/polytomous and singleton cases, missing/zero/huge lengths, exact Unicode,
selection/error order and fresh new-report ownership. It uses Python stdlib only,
records actual source/compiled/output hashes and preserves every old gate. This
self-authored receiving example does not establish third-party adoption.
The verifier binds `MOON_WORK` to its own explicit product/receiver manifest, so
an ancestor workspace left by an earlier recipient is neither inherited nor
rewritten. This nested-workspace case is included in the receiving evidence.

The required independent job also runs `verification/fitch_character_recipient.py`
against a separate public-import configurable character review module on both
targets. Before-edit literal full node/state/change tables and a separate
exhaustive state-labelling minimum validate the exact old ParsimonyResult plus
every readable node and changed-edge annotation, Unicode/missing observations,
structured errors and unchanged input/source hashes. The new receiving module
uses the existing unordered single-character Fitch API; no library algorithm,
public interface, old fixture, model or dependency changes. All old gates stay.

The same required job runs `verification/taxon_rename_recipient.py`. A separate
public module performs simultaneous transactional leaf renames and writes its
actual canonical Newick to a saved UTF-8 file. A distinct executable/process
receives only that exported tree and validates complete hand-fixed graphs,
names/metadata and correspondence rows on JS/Wasm-GC. Per-process numerical
exit/status and full stdout/stderr bytes plus exported-file identities are
recorded. Three focused new native rename groups run in ordinary native gates;
old algorithms, error enums, tests/fixtures and every prior gate stay unchanged.
The bounded gate plan and artifact path schema are described in [CI-PLAN.md](CI-PLAN.md).

CI uses the project's declared compiler `0.10.12+1634b282e`, with Node.js
24.11.0 and Python 3.14. The installer uses the versioned URLs described by the
[official installer](https://cli.moonbitlang.com/install/unix.sh) and checks the
reviewed SHA-256 before extraction:

- Linux SDK: `9bbda7d342fa39654a65c23805e5ff5a3915a26b36627a2565a6b1a99d099e01`.
- Matching core archive: `784a12ce4e204a3a98a0b704a021f747b916412efacd4dfe2f4e5c27ae183ac1`.

The SDK lives only in the CI runner's temporary directory. A new SDK is an
intentional compatibility update; CI does not silently float to a new compiler.
Archive checksum verification follows the [official download instructions](https://www.moonbitlang.com/download/#verifying-binaries).

The reference requirements pin Biopython 1.88 and NumPy 2.5.4. Their generator
is never run to update expected values during CI. Reference packages are used
only for verification and are not MoonBit runtime dependencies.

Each check job saves the actual commit, tracked source hashes, compiled consumer
and library hashes, installed toolchain version, test output and consumer output
as Actions artifacts. The NJ artifact includes per-case JSON and the actual
executable hashes. A workflow file or local test pass alone is not a claim that
remote CI passed; inspect the linked run and required jobs for the exact commit.

## Stable ladderized export gate

`Validate public-package stable ladderized export on both targets` runs
`verification/ladderize_recipient.py` using the unchanged pinned SDK/core and
Python stdlib. Eight hand-authored complete graph/order/terminal-row cases plus
six explicit API errors run on each backend:28 actual calls,16 exported Newick
files and6 compiled artifact identities. Every original/ordered/reparsed node,
all terminal rows, raw stdout/stderr and numeric exit/status are checked.
The consumer has an explicit independent workspace, consumes only public API,
and reparses its actual export in the same process. New native groups verify
order/preserved attributes, degenerate/deep/repeat behavior and private-storage
ownership. All earlier gates stay required; no scientific references are
regenerated for this change. This gate supplies real receiving/export evidence,
not a new renderer, format, scientific metric or external adoption claim.

## Configurable selected-tree artifact and lineage gate

`Validate public-package selected-tree export and source lineage on both targets`
runs `verification/prune_export_recipient.py` with Python stdlib. The separate
public-only application calls unchanged prune once per request, exposes the
whole original witness and source/new trees, and distinguishes nonroot edge
lineage from root compression history. Seven complete literal success fixtures
and eleven request/error fixtures per target give36 real calls,14 actual
Newick exports and6 compiled identities. Check every graph/mapping/path/lineage/
root-history row and every exported byte; preserve full stdout/stderr and
numeric exits/statuses. No native mirror tests or old scientific/reference
scenarios are run locally; required CI keeps all old gates. Root public APIs,
algorithms, parser, fixtures and dependencies stay byte-identical. This is a
configurable artifact workflow, not a new pruning algorithm or reparse claim.
