# Original EXE movement traces

These measurements come from Spelunky 1.1's own F9 screenshots. Coordinates are
logical 320x240 sprite-origin coordinates reported by the extracted-sprite
matcher in `src/tests/original_oracle_analyzer.lua`.

| Trace | Input | Start | End | Displacement | Clone result |
| --- | --- | ---: | ---: | ---: | --- |
| `tutorial-walk-right-10` | Right for 10 runner steps | `(24, 72)` | `(47, 72)` | `(+23, 0)` | Exact |
| `tutorial-jump-held-05` | Jump held through step 5 | `(63, 104)` | `(63, 86)` | `(0, -18)` | Exact |

The matching clone cadence is two input-delay steps followed by horizontal
pixel movement of `2, 3, 3, 3, 3, 3, 3, 3`, for 23 total pixels. This behavior
is locked by `src/tests/platform_player_test.lua`.

The matching held-jump cadence is `-4, -4, -4, -3, -3`, for 18 total pixels.
It includes the original's lagged variable-gravity update and global-time
fractional quantization.

Timed Parallels key holds are not a frame-step interface. Traces that land on a
runner boundary can contain one neighboring step count; use their measured
positions to infer the realized interval and use the extracted GML for exact
per-step ordering.
