# Repository rules

## Purpose

This repository is an experimental portable RATB core. ORCHIDEE 1 remains the
operational reference and must not be modified as a side effect of work here.

## Current boundary

- Input: a canonical external bundle v1 already built and validated by
  ORCHIDEE 1.
- Implemented: TA/DE scope application, RATB plausibility QC, raw global and
  by-type patient-year SPARES-style deduplication, the complete 140-row RATB
  indicator catalogue, annual resistance, annual incidence, and audit
  artifacts.
- Excluded: completion, hospital-specific extraction, external-bundle
  construction, caching, Quarto, HTML, plots, and interpretive reporting.
- Public API: `read_orchidee_bundle()`, `ratb_indicator_catalogue()`, and
  `run_ratb_catalogue()` only. The three focused slice runners are internal
  test and teaching fixtures.

Do not add completion or broaden the public API without an explicit project
decision. The catalogue is declarative data with four closed indicator kinds;
do not turn it into dynamic R expressions or a general rule-engine DSL.

## Change discipline

- Prefer small, reviewable diffs.
- Generalize only after a second real profile requires the same behavior.
- Keep method-specific QC and indicator semantics explicit.
- Preserve stable canonical row IDs and stage-level audit outputs.
- Never treat generated `.Rcheck`, local libraries, tarballs, or ORCHIDEE 1
  artifacts as source files.

## Tests and validation

Every new or edited test must include a short `Why:` comment stating whether
it protects a canonical input contract, engine invariant, method profile, or
regression.

Before committing:

```powershell
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' -e "testthat::test_local('.', reporter = 'summary')"
& 'C:\Program Files\R\R-4.5.3\bin\R.exe' CMD build .
& 'C:\Program Files\R\R-4.5.3\bin\R.exe' CMD check --no-manual orchideecore_0.0.0.9000.tar.gz
```

When current local ORCHIDEE 1 artifacts are available, also run the comparison
entry point documented in `inst/comparison/compare_reference.R`. A matching
final panel alone is insufficient: representatives, class partitions, and
isolate-level results must also match.
