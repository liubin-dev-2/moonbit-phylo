# Published source and bounded compatibility changes

This optional package adapts only the NJ construction subset of
[IvanAXu/BioSeqs 0.1.9](https://mooncakes.io/docs/IvanAXu/BioSeqs@0.1.9),
under the accompanying unmodified `LICENSE-BioSeqs` (Apache-2.0).
The actual registry ZIP was inspected, rather than substituting repository main:

- Registry URL: <https://download.mooncakes.io/user/IvanAXu/BioSeqs/0.1.9.zip>
- ZIP SHA-256: `a9c20fc628548e01c1fe6ce5e1ea7fb3a73f068618898a7b337847071b4d5435`.
- Published `src/tree_construction.mbt` SHA-256:
  `be34ae592de9e5a5dcd6c231f5baf867d56413976e10ad4008589b62f1b35f3e`.
- Relevant blocks: `BuildNode`, `build_node_leaf`, `build_node_internal`,
  `build_nj`, `copy_matrix` and the node-to-tree conversion pattern.
- There was no NOTICE file in the published archive. No UPGMA, WPGMA,
  sequence calculator, alignment or other BioSeqs module is integrated.

Reuse decision: the full published source failed to compile with the recorded
2026-09 SDK (including the reserved identifier `var` in `decoupler.mbt`).
An isolated harness then compiled the **unchanged** published NJ file with only
the exact original Clade definitions it requires. Both JS and Wasm-GC returned
NaN/Infinity for finite large inputs, and lost the smallest positive binary64
two-tip distance when halving it into two branches. A three-point negative limb
was returned as -0.5: the published routine does **not** silently clip it.
These observations are narrower than a full-package compatibility claim.

`biose_nj.mbt` prominently marks its changes. It keeps the published row-sum/Q
recurrence, strict minimum comparison, two-limb merge equations, distance
reduction and keep-then-append order. Unused node IDs/heights and the Clade
conversion are replaced with a small private node and quoted Newick conversion
into the existing core. Added compatibility policy:

1. Validate and copy a 2..128 exact-label matrix before canonical sorting. The
   diagonal and symmetry tolerance are exactly zero; signed zero is normalized.
2. Keep the original arithmetic path first. On construction overflow only, retry
   once from canonical input in exact power-of-two units (divide by256, restore
   exported limbs by256). Every converted input must round-trip exactly and
   every nonzero retry distance intermediate must be normal binary64; reject
   unsafe gradual underflow and nonzero division becoming zero. Restored limbs
   and existing exact core paths must remain representable. Negative diagnostics
   use original units. This conservatively extends range without promising all
   finite matrices, clipping branches or changing the recurrence/tie order.
3. Replace the finite Q sentinel with an optional initial minimum. Exact computed
   Q ties choose the first pair in canonical UTF-16 lexical/active order.
4. Reject negative limbs, including negative zero from underflow. No clipping or
   redistribution. A negative three-star numerator is checked before division.
5. For two tips use zero plus the full distance to preserve their path; finish
   three active clusters as an unrooted star. Zero branches remain present.
6. Return the existing unrooted core tree, fitted paths and signed residuals;
   RMS is over unordered pairs with scaling to avoid squared-value overflow.

The core module identity, root imports, API and exact path/PD arithmetic are
unchanged. This package has no third-party package dependency; the original
root package never imports it. NJ is a classic algorithm, not a new estimator.
It does not infer a biological root, align sequences, estimate substitution
models, bootstrap, or guarantee unbiased or true-ancestor reconstruction.
