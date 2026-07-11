# Handoff

## Current status

As of 2026-07-11, `orchideecore` executes the complete raw RATB catalogue with
one primary profile:

- `ratb_catalogue_raw_patient_year_v1` (140 indicators, global and by-type).

The three focused compatibility profiles remain:

- `ecoli_c3g_raw_global_patient_year_v1`
- `saureus_methicillin_raw_global_patient_year_v1`
- `kpneumo_blse_raw_global_patient_year_v1`

Completion is intentionally absent.

## Confirmed evidence

Against ORCHIDEE 1 commit
`89128b9a514f5e25d015cb4fe0c4e9f0a66eacb3`, the current CHU self-handoff
bundle produces identical:

- analytic-scope and post-QC row counts;
- representative key sets;
- SPARES class partitions;
- isolate-level indicator results;
- annual resistance panels;
- annual incidence outputs.

Reference counts are 8,356 E. coli, 3,405 S. aureus, and 1,728 K. pneumoniae
representatives. Bundle hashes and the complete gate are recorded in
`inst/validation/reference-gate-2026-07-11.md`.

The full catalogue gate additionally confirms identical global and by-type
representatives and class partitions, plus identical complete proportion and
incidence panels and isolate-level results for all 140 indicators. The packaged
catalogue has MD5
`bebc2da626aa22e881fa1f6786d1a459`, identical to ORCHIDEE 1.

The package now has 16 specification/invariant test cases. Every added test
states the contract it protects.

## Ownership split

ORCHIDEE 1 owns:

- hospital adapters and site-input builders;
- the complete canonical bundle validator;
- operational production and reporting;
- the current methodological reference implementation.

This repository owns only the portable downstream experiment and its
comparison evidence.

## Known limits

- The comparisons start at the canonical bundle. They do not independently
  validate raw extraction, diagnostic/screening mapping, unit mapping, or the
  episode-level construction of hospital nights.
- The reference harnesses currently depend on local ORCHIDEE 1 artifacts named
  `ratb_scope_cache`, `completion_datasets`, and `dedup_results`. It reads only
  the `sir_wide_raw` branch; despite the artifact name, no completion profile
  is executed in the new core.
- There is no remote repository or CI configuration yet.
- The final uncached complete new-core run took 269.11 seconds on the reference
  machine. The full isolate-level new-plus-reference gate took 312.8 seconds.
  Performance is a known limit and has not been declared better than ORCHIDEE
  1.

## Next decisions

1. Review and ratify `run_ratb_catalogue()` and its output contract.
2. Profile the two SPARES passes before deciding whether performance work or a
   deliberately external cache is justified.
3. Decide where the repository will be hosted and add CI for package tests and
   `R CMD check` without committing private reference data.
4. Keep completion as a separate future decision; it is not implied by this
   handoff.
