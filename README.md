# orchideecore

`orchideecore` is a portable analytical-core experiment, not yet a replacement
for operational ORCHIDEE 1.

The primary path now executes the complete 140-row RATB catalogue:

```text
validated canonical bundle v1
  -> sample TA/DE scope
  -> RATB biological plausibility QC
  -> raw patient-year SPARES deduplication (global and by sample type)
  -> four closed indicator kinds
  -> 136 annual proportion indicators
  -> 135 annual incidence indicators
```

The original E. coli C3G, S. aureus methicillin, and K. pneumoniae BLSE slice
functions remain available as small compatibility and teaching entry points.
Completion is explicitly out of scope. The package also contains no local
hospital adapter, cache, Quarto code, plots, HTML, or implicit global setup.

## Input boundary

The package consumes the four files built and validated by ORCHIDEE 1:

- `sir_wide.rds`
- `sir_wide_meta.rds`
- `sample_scope_reference.rds`
- `denominator_bundle.rds`

Validation of the complete external contract remains owned by ORCHIDEE 1.
This package adds only the assertions required to execute this slice safely.

## Minimal run

```r
bundle <- read_orchidee_bundle("path/to/validated_bundle")
result <- run_ratb_catalogue(bundle)

result$proportion_annual
result$incidence_annual
result$dedup$global$representatives
result$dedup$by_type$representatives
```

The result also contains the packaged catalogue, row-level scope and
plausibility decisions, both SPARES class maps, isolate-level results, and
population counts. `ratb_indicator_catalogue()` exposes the fixed catalogue for
inspection.

## Method profiles

The complete profile is named `ratb_catalogue_raw_patient_year_v1`.

- All 140 definitions are copied byte-for-byte from the ORCHIDEE 1 publication
  catalogue.
- Indicator behavior is limited to `molecule_direct`, `class_any_r`,
  `molecule_priority`, and `phenotype_flag`.
- Deduplication is computed once globally and once with sample type in the
  patient-year key; indicators reuse those representatives.
- Phenotype flags are finalized at retained-class level.
- The catalogue is data, not executable R and not a general rule language.

The three original focused profiles remain:

The first profile is fixed in code and named
`ecoli_c3g_raw_global_patient_year_v1`.

- C3G: cefotaxime, ceftazidime, ceftriaxone.
- C3G result: `R` if any component is resistant; `O` if no component is
  tested as `S` or `R`; otherwise `S`.
- Deduplication group: patient, calendar year, bacterium.
- Compatibility: no overlapping `S`/`R` conflict across any observed
  antibiotic or the BLSE/carbapenemase S/R proxies.
- Representative: most complete row, followed by deterministic event,
  document, isolate, and row-order tie-breaks.
- Completion: not applied.

The second profile is named
`saureus_methicillin_raw_global_patient_year_v1`.

- Methicillin: cefoxitin first, oxacillin as fallback.
- A row carrying discordant informative cefoxitin and oxacillin is excluded by
  the current biological plausibility rule before deduplication.
- Deduplication and audit contracts are shared with the first profile.
- Completion: not applied.

The third profile is named `kpneumo_blse_raw_global_patient_year_v1`.

- BLSE is finalized at retained-class level after deduplication.
- The proportion denominator is all retained isolates.
- Proportion and incidence retain the distinct publication IDs defined by the
  ORCHIDEE 1 indicator specification.
- Completion: not applied.

## Current reference gate

The complete real-data comparison passed on 2026-07-11. All 140 indicators,
global and by-type representatives, both SPARES class partitions, the complete
isolate-level indicator result set, annual proportion panel, and annual
incidence panel were identical to ORCHIDEE 1. The focused-profile evidence
remains in
`inst/validation/reference-gate-2026-07-11.md`; the full gate is recorded in
`inst/validation/catalogue-reference-gate-2026-07-11.md`.

Before the singleton fast path, two staged uncached runs took 268.89 and 259.52
seconds. After the change, the complete reference gate took 216.93 seconds and
the staged profile took 202.11 seconds. The equivalent uncached ORCHIDEE 1 run
took 263.67 seconds. The detailed profile is recorded in
`inst/validation/performance-profile-2026-07-11.md`.
