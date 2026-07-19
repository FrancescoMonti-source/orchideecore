# Handoff

## Current status

As of 2026-07-19, `orchideecore` executes the complete raw RATB catalogue with
one primary profile:

- `ratb_catalogue_raw_patient_year_v1` (140 indicators, global and by-type).

The three focused compatibility profiles remain internal:

- `ecoli_c3g_raw_global_patient_year_v1`
- `saureus_methicillin_raw_global_patient_year_v1`
- `kpneumo_blse_raw_global_patient_year_v1`

Completion is intentionally absent.

The GitHub repository is public and `main` is protected. Routine changes enter
through a pull request whose `R-CMD-check` status must pass; owner bypass is
retained only for emergencies.

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
The gate was rerun after API ratification and passed at every comparison level.

On 2026-07-19, the Rouen adapter bundle v2 passed the strict upstream validator,
the canonical-runtime smoke, and complete catalogue execution in this core.
The manifest correctly reports canonical input v2 while retaining
`ratb_catalogue_result_v1`; all catalogue cardinality, key-uniqueness, scope,
and isolate-result vocabulary checks passed. Only non-identifying aggregate
evidence is retained in
`inst/validation/rouen-bundle-v2-portability-gate-2026-07-19.md`.

The package now has 21 specification/invariant test cases. Every added test
states the contract it protects.

The ratified public API contains only `read_orchidee_bundle()`,
`ratb_indicator_catalogue()`, and `run_ratb_catalogue()`. The complete runner
returns `ratb_catalogue_result_v1`; empty isolate and proportion outputs retain
their typed schemas, and transient representative-order columns are not
exposed.

Canonical bundle v1 and v2 are accepted as inputs. Missing contract metadata is
the legacy v1 form. Bundle v2 is accepted only with
`sejuf_semantics = "hospitalization_unit_at_sampling"`, and the result manifest
reports the validated input contract without changing the v1 output schema or
method profile.

## Ownership split

ORCHIDEE 1 owns:

- hospital adapters and site-input builders;
- the complete canonical bundle validator;
- operational production and reporting;
- the current methodological reference implementation.

This repository owns only the portable downstream experiment and its
comparison evidence.

## Ratified upstream sample-attribution decision

This decision applies to the hospital/site adapter that builds the canonical
bundle. It does not expand the current `orchideecore` boundary: this package
continues to consume an already validated bundle.

The upstream builder must keep three choices independent:

- sample attribution context: hospitalisation unit at sample time by default,
  or the unit recorded by microbiology as an explicit sensitivity setting;
- perimeter filters: configured UM, UF, TA, and DE values;
- output stratification: the dimensions used only for final aggregation.

The default hospitalisation-attribution path is:

1. Treat the microbiology sample datetime as a point in time.
2. Start from the uncollapsed PMSI intervals returned by `redsan` with
   `source_policy = "c_over_dw"` (the PMSI default from `redsan` 0.2.0). This
   applies the explicit `SRC` precedence without replacing the retained
   intervals with unit-level `min(DATENT)` / `max(DATSORT)` bounds.
3. Use `EVTID` to identify the hospital stay and retain `PATID` in the join as
   a provenance guard. Keep intervals satisfying
   `DATENT <= sample_datetime < DATSORT`.
4. When exactly one complete UM+UF pair is active, assign that hospitalisation
   unit even if other active records have an incomplete unit pair; retain the
   incomplete-record count in the audit.
5. When several complete UM+UF pairs are active, assign one only if exactly one
   matches the UM+UF recorded by microbiology. Otherwise record
   `ambiguous_hebergement`.
6. When no complete UM+UF pair is active, record `unassigned_hebergement` and
   distinguish no active interval from incomplete active records in the audit.
7. Never fall back automatically from datetime matching to calendar-date
   matching.

Both unresolved statuses are excluded from the hospitalisation-based
analytical perimeter and retained in the audit with their reason. TA/DE is
joined to the selected unit only after attribution. The incidence denominator
continues to come from PMSI hospitalisation activity on the same unit mapping.

The upstream builder configuration exposes one central choice between
`hebergement` (default) and `prelevement`; this is not a downstream core knob.
Attribution, perimeter filters, and output stratification do not alter the
patient-year deduplication keys. The original bundle v1 and its ratified
comparison gate remain unchanged; the successor v2 contract is validated as a
separate portability gate.

## Known limits

- The comparisons start at the canonical bundle. They do not independently
  validate raw extraction, diagnostic/screening mapping, unit mapping, or the
  episode-level construction of hospital nights.
- The reference harnesses currently depend on local ORCHIDEE 1 artifacts named
  `ratb_scope_cache`, `completion_datasets`, and `dedup_results`. It reads only
  the `sir_wide_raw` branch; despite the artifact name, no completion profile
  is executed in the new core.
- GitHub Actions runs the package tests and `R CMD check` on Ubuntu with the
  repository's public synthetic fixtures. The real-data comparison harness is
  intentionally excluded because it depends on local ORCHIDEE 1 artifacts.
- The external-site wiki is working onboarding guidance, not yet a validated
  Rennes contract. A user-led Rennes walkthrough is expected to expose and
  correct imprecisions upstream in ORCHIDEE 1 before its resulting canonical
  bundle is treated as a portability gate here.
- Before the singleton fast path, two staged uncached new-core runs took 268.89
  and 259.52 seconds. After it, the complete reference gate took 216.93 seconds
  and the staged profile took 202.11 seconds. The equivalent uncached ORCHIDEE
  1 run took 263.67 seconds.
- About 96% of new-core runtime is in the two SPARES passes. R profiling points
  to repeated EVT/ELT ordering, especially during representative selection.
  Singleton classes are 84.4% of global classes and 90.4% of by-type classes.

## Next decisions

1. Adopt canonical bundle v2 as an optional operational input in ORCHIDEE 1,
   keeping the current CHU-native route as the default and keeping CHU-only QA
   distinct from adapter-local audit evidence.
2. Continue the Rennes onboarding walkthrough and run an independent-site
   portability gate when its validated bundle is available.
3. Keep completion as a separate future decision; it is not implied by this
   handoff.
