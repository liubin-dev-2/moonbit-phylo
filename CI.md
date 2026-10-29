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
