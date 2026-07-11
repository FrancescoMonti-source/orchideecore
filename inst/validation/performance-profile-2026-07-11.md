# Performance profile: 2026-07-11

This profile compares uncached raw-catalogue execution. It does not compare
ORCHIDEE 1 notebook rendering, completion strategies, or cache loading.

## Reference workload

- same CHU self-handoff canonical bundle used by the complete reference gate
- same raw post-QC microbiology population
- global patient-year SPARES
- by-type patient-year SPARES
- 140 indicator definitions
- 136 annual proportion definitions
- 135 annual incidence definitions
- R 4.5.3 on the same Windows reference machine

The reusable entry point is `inst/profiling/profile_catalogue.R` with mode
`new` or `v1`.

## Whole-pipeline timings

| Implementation | Run | Measured stages (s) | Peak memory (MB) |
| --- | ---: | ---: | ---: |
| New core | 1 | 268.89 | not captured |
| New core | 2 | 259.52 | 633.2 |
| ORCHIDEE 1 | 1 | 263.67 | 716.0 |

The two new-core timings average 264.21 seconds. The observed runtime difference
from ORCHIDEE 1 is smaller than the between-run variation, so these measurements
do not support a speed advantage for either implementation. The new core used
82.8 MB (11.6%) less peak memory in the measured runs.

The new-core total includes canonical bundle scope and plausibility QC plus
materialization of 855,212 isolate-level indicator rows. The ORCHIDEE 1 profile
starts from its saved raw post-QC dataset and builds panels directly.

## Staged timings

| Stage | New core run 2 (s) | ORCHIDEE 1 (s) |
| --- | ---: | ---: |
| Input read / preparation | 1.69 | 1.94 |
| SPARES global | 119.58 | 117.95 |
| SPARES by type | 128.38 | 131.89 |
| Isolate-level results | 2.97 | not materialized |
| Proportion panel | 6.24 | 7.78 |
| Incidence panel | 0.66 | 4.11 |

The two new-core SPARES passes account for 247.96 of 259.52 seconds (95.5%).
Indicator derivation and both publication panels are not the performance
bottleneck.

## Internal new-core SPARES profile

`inst/profiling/profile_new_spares_global.R` sampled one global pass with
`Rprof` every 10 ms. Profiling overhead increased elapsed time, so percentages
are more meaningful than the absolute profiled duration.

Highest inclusive sampled costs:

- `.order_keys`: 54.8%
- `.representative_order`: 32.5%
- `.derive_elt_order`: 29.9%
- `.class_order`: 23.3%
- `rbind`: 10.3%

The discordance matrix did not appear among the dominant inclusive costs.

## Smallest optimization candidate

The current implementation recomputes representative-order keys for every
phenotype class, including classes containing one row. Cached reference class
maps show:

- global: 20,101 / 23,825 classes are singleton (84.4%)
- by type: 23,542 / 26,029 classes are singleton (90.4%)

Selecting the sole row directly is semantics-preserving and avoids unnecessary
EVT/ELT derivation for most classes. This candidate has not been implemented.
Any implementation must pass the complete representative, partition,
isolate-level, proportion, and incidence reference gate before acceptance.

## Singleton fast-path result

The candidate was implemented as an exact fast path: when a phenotype class
contains one row, that row is selected directly. Multi-row classes still use
the unchanged representative-order function.

| Stage | Before (s) | After (s) | Change |
| --- | ---: | ---: | ---: |
| SPARES global | 119.58 | 94.73 | -20.8% |
| SPARES by type | 128.38 | 95.67 | -25.5% |
| Both SPARES passes | 247.96 | 190.40 | -23.2% |
| Complete staged pipeline | 259.52 | 202.11 | -22.1% |

The complete reference harness measured 269.11 seconds before the change and
216.93 seconds afterward (-19.4%). The equivalent ORCHIDEE 1 uncached profile
was 263.67 seconds.

The post-change gate confirmed identical:

- global and by-type representative sets
- global and by-type class partitions
- all isolate-level indicator results
- complete annual proportion panel
- complete annual incidence panel

Memory was not an optimization target. The measured post-change peak remained
in the same modest range and is treated as run-to-run variation rather than a
performance claim.
