# Reference gate: 2026-07-11

This note records the first real-data comparisons of the bounded
`ecoli_c3g_raw_global_patient_year_v1` and
`saureus_methicillin_raw_global_patient_year_v1` profiles, plus the phenotype
profile `kpneumo_blse_raw_global_patient_year_v1`. It is characterization
evidence, not authorization to replace ORCHIDEE 1.

## Reference

- ORCHIDEE 1 commit: `89128b9a514f5e25d015cb4fe0c4e9f0a66eacb3`
- R: 4.5.3
- Bundle: current CHU self-handoff canonical bundle
- Comparison entry point: `inst/comparison/compare_reference.R`

Bundle MD5 hashes:

- `sir_wide.rds`: `257006ec775d3c269f1ca85b56ad0ab5`
- `sir_wide_meta.rds`: `17a5d297c5b62aef25d99ebda2cfa408`
- `sample_scope_reference.rds`: `b4e856b3eeed68769d1974c46fd3894c`
- `denominator_bundle.rds`: `8c597f1cb305b95ea573352d6f173c64`

## Result

- analytic-scope row count: identical
- post-QC E. coli row count: identical
- ORCHIDEE 1 retained representatives: 8,356
- new-core retained representatives: 8,356
- representative keys missing from new core: 0
- representative keys extra in new core: 0
- E. coli SPARES class partitions: identical
- isolate-level E. coli C3G results: identical
- annual E. coli C3G resistance panel: identical
- annual E. coli C3G incidence: identical
- S. aureus analytic-scope row count: identical
- post-QC S. aureus row count: identical
- ORCHIDEE 1 retained S. aureus representatives: 3,405
- new-core retained S. aureus representatives: 3,405
- S. aureus representative keys missing from new core: 0
- S. aureus representative keys extra in new core: 0
- S. aureus SPARES class partitions: identical
- isolate-level S. aureus methicillin results: identical
- annual S. aureus methicillin resistance panel: identical
- annual S. aureus methicillin incidence: identical
- K. pneumoniae analytic-scope row count: identical
- post-QC K. pneumoniae row count: identical
- ORCHIDEE 1 retained K. pneumoniae representatives: 1,728
- new-core retained K. pneumoniae representatives: 1,728
- K. pneumoniae representative keys missing from new core: 0
- K. pneumoniae representative keys extra in new core: 0
- K. pneumoniae SPARES class partitions: identical
- isolate-level K. pneumoniae BLSE results: identical
- annual K. pneumoniae BLSE-positive proportion: identical
- annual K. pneumoniae BLSE-positive incidence: identical
- package check: `R CMD check --no-manual`, status OK

## Interpretation boundary

The comparison starts from the canonical bundle and current ORCHIDEE 1
artifacts. It does not independently validate the raw CHU extraction, local
diagnostic/screening decision, unit mapping, or episode-level construction of
hospital nights. Completion was not executed by the new core.
