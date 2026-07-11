# orchideecore

`orchideecore` is a bounded experiment, not a replacement for ORCHIDEE 1.

The implemented profiles are deliberately limited to:

```text
validated canonical bundle v1
  -> sample TA/DE scope
  -> E. coli selection
  -> C3G-relevant biological plausibility QC
  -> raw global patient-year SPARES-style deduplication
  -> annual E. coli / C3G resistance proportion
  -> annual incidence density per 1,000 hospital nights

validated canonical bundle v1
  -> sample TA/DE scope
  -> K. pneumoniae selection
  -> intrinsic-resistance plausibility QC
  -> raw global patient-year SPARES-style deduplication
  -> class-level BLSE finalization
  -> annual BLSE-positive proportion and incidence density

validated canonical bundle v1
  -> sample TA/DE scope
  -> S. aureus selection
  -> oxacillin/cefoxitin plausibility QC
  -> raw global patient-year SPARES-style deduplication
  -> annual S. aureus / methicillin resistance proportion
  -> annual incidence density per 1,000 hospital nights
```

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
result <- run_ecoli_c3g_slice(bundle)
methicillin <- run_saureus_methicillin_slice(bundle)
blse <- run_kpneumo_blse_slice(bundle)

result$resistance_annual
result$incidence_annual
```

The result also contains row-level scope and plausibility decisions, class
membership, representatives, isolate-level C3G results, and population counts.

## Method profile

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

The profile should not be generalized until this slice and a second,
methodologically different slice have passed comparison against ORCHIDEE 1 and
specification fixtures.

## Current reference gate

All three real-data comparisons passed on 2026-07-11. Scope and post-QC counts,
all 8,356 E. coli representatives, all 3,405 S. aureus representatives, all
1,728 K. pneumoniae representatives, SPARES class partitions, isolate-level
results, annual panels, and annual incidence outputs were identical to
ORCHIDEE 1. The frozen evidence and bundle hashes are recorded in
`inst/validation/reference-gate-2026-07-11.md`.
