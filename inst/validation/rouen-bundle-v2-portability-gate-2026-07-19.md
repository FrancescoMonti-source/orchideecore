# Rouen bundle v2 portability gate — 2026-07-19

## Scope

This gate exercises the portable core against the canonical bundle v2 built by
the Rouen adapter merged in ORCHIDEE 1 at commit
`af657220b93317f2a690f562e453591dc5042644`. The core execution used commit
`a0eb991dbd1e1a050049c83b9708043d4dc83b72` and R 4.5.3.

Only non-identifying aggregate evidence is retained here. The bundle, local
paths, hashes, identifiers, unit codes, representative rows, class maps,
isolate rows, indicator values, and denominator values are not recorded.

## Gates

The ORCHIDEE 1 strict v2 validator passed, followed by the canonical-runtime
smoke. The core then ran `read_orchidee_bundle()` and
`run_ratb_catalogue()` from source.

The upstream command sequence was:

```text
Rscript scripts/validate_external_bundle.R <bundle_dir> --contract=v2 --strict-preferred
Rscript scripts/smoke_external_runtime_inputs.R <bundle_dir> --contract=v2 --strict-preferred
```

The core run loaded the committed package source, read `<bundle_dir>`, executed
the complete catalogue, and stopped unless all checks listed below were true.

The full catalogue run completed in 175.83 seconds and reported:

- input contract: `v2`;
- output contract: `ratb_catalogue_result_v1`;
- method profile: `ratb_catalogue_raw_patient_year_v1`;
- completion applied: `FALSE`;
- years represented: 2022, 2023, 2024;
- catalogue definitions: 140;
- proportion indicators: 136;
- incidence indicators: 135;
- proportion-panel rows: 5,293;
- incidence-panel rows: 405;
- isolate-result rows: 773,567.

Stage-level counts were:

| Stage | Rows |
|---|---:|
| canonical bundle | 48,600 |
| analytic scope | 26,434 |
| plausibility QC | 26,427 |
| global representatives | 21,754 |
| by-type representatives | 23,794 |

The gate also confirmed:

- only `global` and `by_type` scopes are emitted;
- proportion, incidence, and isolate-result keys are unique;
- isolate-level indicator results use only `R`, `S`, and `O`;
- the input v2 contract does not change the v1 result schema or method profile.

## Comparison boundary

The ORCHIDEE 1 comparison harness was deliberately not run for this bundle. It
currently reads CHU reference representatives and class maps from local legacy
artifacts, so pairing it with the Rouen v2 bundle would mix two different
provenance chains. A future same-bundle comparison requires reference artifacts
regenerated and isolated from that same input.
