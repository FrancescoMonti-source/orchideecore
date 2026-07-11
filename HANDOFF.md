# Handoff

## Current status

As of 2026-07-11, `orchideecore` is a bounded package experiment with three
raw, global, patient-year profiles:

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

The package has 12 specification/invariant tests and passes
`R CMD check --no-manual` with status OK under R 4.5.3.

## Ownership split

ORCHIDEE 1 owns:

- hospital adapters and site-input builders;
- the complete canonical bundle validator;
- operational production and reporting;
- the current methodological reference implementation.

This repository owns only the portable downstream experiment and its
comparison evidence.

## Known limits

- The comparison starts at the canonical bundle. It does not independently
  validate raw extraction, diagnostic/screening mapping, unit mapping, or the
  episode-level construction of hospital nights.
- The reference harness currently depends on local ORCHIDEE 1 artifacts named
  `ratb_scope_cache`, `completion_datasets`, and `dedup_results`. It reads only
  the `sir_wide_raw` branch; despite the artifact name, no completion profile
  is executed in the new core.
- There is no remote repository or CI configuration yet.
- The comparison recomputes each taxon independently and currently takes about
  100 seconds on the reference machine.

## Next decisions

1. Review and ratify the three-profile public API before adding another
   profile.
2. Decide where the repository will be hosted and add CI for package tests and
   `R CMD check` without committing private reference data.
3. Decide whether the next method profile should extend phenotype coverage or
   whether the current experiment is sufficient for an architectural gate.
4. Keep completion as a separate future decision; it is not implied by this
   handoff.
