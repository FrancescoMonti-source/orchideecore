# Handoff

## Current status

As of 2026-07-19, `orchideecore` is a concluded, feature-frozen experiment. Its
final implementation executes the complete raw RATB catalogue with one primary
profile:

- `ratb_catalogue_raw_patient_year_v1` (140 indicators, global and by-type).

The three focused compatibility profiles remain internal:

- `ecoli_c3g_raw_global_patient_year_v1`
- `saureus_methicillin_raw_global_patient_year_v1`
- `kpneumo_blse_raw_global_patient_year_v1`

Completion is intentionally absent.

Operational development now belongs to ORCHIDEE. This repository remains an
independent package, comparison harness, and audit trail; it is not an ORCHIDEE
runtime dependency. The GitHub repository is public, `main` is protected, and
GitHub archival is the intended final state after this close-out.

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

The final same-bundle comparison used ORCHIDEE commit
`f0592a4c1eeb2da2b3d1ed3a9ce9c1038fb01535` and `orchideecore` commit
`976c4e8d657403f7af101c8c832f26d5e30ac374`. The exact bundle was matched to
the isolated ORCHIDEE runtime cache before execution. Global and by-type
representatives, both SPARES partitions, all 773,567 isolate-level indicator
results, the 5,293-row annual proportion panel, and the 405-row annual incidence
panel were identical at tolerance zero. The raw, non-completed branch was used
on both sides. Only aggregate evidence is retained in
`inst/validation/rouen-bundle-v2-same-bundle-gate-2026-07-19.md`.

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
- the default bundle-v2 operational runtime, production, and reporting;
- the current methodological reference implementation.

This repository retains only the frozen portable downstream experiment and its
comparison evidence. Future operational and methodological changes belong in
ORCHIDEE unless the standalone package is explicitly reactivated.

## Ratified upstream sample-attribution decision

This historical decision applies to the hospital/site adapter that builds the
canonical bundle. It does not expand the `orchideecore` boundary: this package
continues to consume an already validated bundle. The current ORCHIDEE
documentation is authoritative for its operational implementation.

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
- The reference harnesses depend on a local canonical bundle and isolated
  ORCHIDEE artifacts. The complete catalogue comparison reads only the
  `sir_wide_raw` branch of `completion_datasets` and `dedup_results`; despite
  the artifact names, no completion profile is executed in the core.
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

## Reactivation boundary

No further feature development is planned in this repository. Continue the
Rennes onboarding, future portability gates, adapter work, and operational
method changes in ORCHIDEE.

Reactivate `orchideecore` only after an explicit decision to maintain an
independently released package or a second consumer outside ORCHIDEE. Completion
remains a separate future decision and is not implied by this close-out.
