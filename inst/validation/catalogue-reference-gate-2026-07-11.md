# Complete catalogue reference gate: 2026-07-11

This gate evaluates the complete raw RATB catalogue. It is evidence for the
portable analytical core, not authorization to replace operational ORCHIDEE 1.

## Reference

- ORCHIDEE 1 commit: `89128b9a514f5e25d015cb4fe0c4e9f0a66eacb3`
- R: 4.5.3
- Input: current CHU self-handoff canonical bundle
- Catalogue rows: 140 active annual indicators
- Catalogue MD5: `bebc2da626aa22e881fa1f6786d1a459`
- Comparison entry point: `inst/comparison/compare_catalogue_reference.R`

## Exact comparison result

- global representative key set: identical
- by-type representative key set: identical
- global SPARES class partitions: identical
- by-type SPARES class partitions: identical
- all isolate-level indicator results: identical
- complete annual proportion panel: identical
- complete annual incidence panel: identical
- indicators compared: 140 / 140

The comparison covers 136 published proportion definitions and 135 published
incidence definitions. Publication-only phenotype IDs explain why those counts
are not both 140.

## Performance observation

- new core before singleton fast path: 269.11 elapsed seconds
- new core after singleton fast path: 216.93 elapsed seconds
- complete post-fast-path isolate-level new-core plus ORCHIDEE 1 gate:
  263.0 elapsed seconds

The post-fast-path gate retained exact equality at every comparison level. The
dominant work remains the pair of full SPARES passes (global and by sample
type). Caching remains outside the core and requires a separate design
decision.

## Interpretation boundary

The comparison starts from the canonical bundle and current ORCHIDEE 1 raw
artifacts. It does not independently validate CHU extraction, local diagnostic
scope decisions, unit mapping, or construction of hospital-night denominators.
Completion and reporting are not executed by the new core.
