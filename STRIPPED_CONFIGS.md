# Stripped multiplier configurations

This branch is for physical experiments that isolate whether a smaller latency-tolerant
multiplier can save core energy once unused multiplier RTL is removed.

Rules:

- The normal `biriscv_multiplier` remains present in every configuration.
- All experimental multiplier variants except `mule3n` and `mule5n` are tied off at
  `riscv_core` top level.
- `mule3n` is instantiated only when `SUPPORT_MULE3N=1`.
- `mule5n` is instantiated only when `SUPPORT_MULE5N=1`.
- Fetch/issue custom multiplier flags are forced to zero for every disabled unit.
- The intended measurement branches are:
  - `exp-strip-mul-only`: `SUPPORT_MULE3N=0`, `SUPPORT_MULE5N=0`
  - `exp-strip-mul-mule3n`: `SUPPORT_MULE3N=1`, `SUPPORT_MULE5N=0`
  - `exp-strip-mul-mule5n`: `SUPPORT_MULE3N=0`, `SUPPORT_MULE5N=1`

The benchmark steering policy must route only to units present in the branch being
measured.
