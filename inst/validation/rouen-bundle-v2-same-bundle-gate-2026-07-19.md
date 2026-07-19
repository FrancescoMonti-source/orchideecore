# Rouen bundle v2 same-bundle reference gate — 2026-07-19

## Scope

This final gate compares ORCHIDEE and `orchideecore` from the same validated
canonical bundle v2. It closes the provenance gap deliberately left by the
earlier portability smoke: the ORCHIDEE reference artifacts and the core run
were derived from the exact same four bundle files.

The reference implementation was ORCHIDEE commit
`f0592a4c1eeb2da2b3d1ed3a9ce9c1038fb01535`. The independent package was
`orchideecore` commit `976c4e8d657403f7af101c8c832f26d5e30ac374`. The run used
R 4.5.3.

Only non-identifying aggregate evidence is retained here. Bundle contents,
local paths, file signatures, patient and stay identifiers, unit codes,
representative rows, class maps, isolate rows, indicator values, and denominator
values are not recorded.

## Provenance guard

Before comparison, the four bundle-file digests were checked against the
runtime input signature stored with the isolated ORCHIDEE deduplication cache.
All four matched. The comparison then used only the cache's `sir_wide_raw`
branch; no completion profile was applied on either side.

The public catalogue definitions used by ORCHIDEE and the catalogue packaged in
`orchideecore` were also byte-identical.

## Comparison

The existing `inst/comparison/compare_catalogue_reference.R` harness executed
`read_orchidee_bundle()` and `run_ratb_catalogue()` from the core source. It
compared:

- global and by-type representative sets by stable canonical row ID;
- global and by-type SPARES partitions by row membership, independently of
  transient numeric class labels;
- isolate-level results by canonical row, scope, sample type, and indicator;
- annual proportion and incidence panels by indicator, scope, sample type, and
  year.

Counts, `R`/`S`/`O` results, numerators, denominators, and rates were compared
with tolerance zero. The core calculation completed in 151.31 seconds.

## Result

All comparison gates passed:

| Artifact | Aggregate size | Result |
|---|---:|---|
| Post-QC analytical rows | 26,427 | reconciled |
| Global representatives | 21,754 | identical |
| By-type representatives | 23,794 | identical |
| Global SPARES partitions | 26,427 rows | identical |
| By-type SPARES partitions | 26,427 rows | identical |
| Isolate-level indicator results | 773,567 | identical |
| Annual proportion panel | 5,293 rows | identical |
| Annual incidence panel | 405 rows | identical |

The run executed all 140 catalogue definitions. This establishes exact
same-input agreement between the two downstream implementations at the
representative, partition, isolate-result, and final-panel levels.

This gate does not independently validate hospital extraction or adapter logic;
those remain upstream ORCHIDEE responsibilities. It does provide the final
evidence needed to retain `orchideecore` as a frozen, reproducible reference
rather than an active operational dependency.
