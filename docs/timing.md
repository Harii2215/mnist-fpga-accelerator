# Timing & Constraints

Target board: **Xilinx Artix-7 AC701** — `XC7A200T-2FBG676C`, speed grade **-2**.

## System clock (AC701)

| Net      | FPGA pin | I/O standard | Frequency |
|----------|----------|--------------|-----------|
| SYSCLK_P | R3       | LVDS_25      | 200 MHz   |
| SYSCLK_N | P3       | LVDS_25      | (diff)    |

Source: AC701 board user guide (UG952), bank 34 fixed 200 MHz SiTime oscillator.

## Why a *timing-only* XDC

`nn_accel_top` exposes an **internal SoC interface** (CSR bus, a 128-bit DRAM
read port, an 80-bit packed-logits output). These are not meant to be wired to
physical device pins, so the constraint file:

- declares the clock with `create_clock`,
- applies modest `set_input_delay` / `set_output_delay` budgets (15% of period),
- cuts the async `rst_n` with `set_false_path`,
- assigns **no** `PACKAGE_PIN` / `IOSTANDARD` (those belong in a board wrapper).

This produces a meaningful **register-to-register Fmax** without inventing fake
pinouts. For on-board bring-up, add an `ac701_top.sv` wrapper (IBUFDS on R3/P3,
reset on U4, status on the 4 user LEDs) plus a pin-LOC XDC.

## Setting the target frequency

Edit one line in `constraints/nn_accel_timing.xdc`:

```tcl
set CLK_PERIOD_NS 10.000   ;# 100 MHz  (5.000 = 200 MHz, 8.000 = 125 MHz)
```

## Closing timing

If a `register -> output-port` path (e.g. `u_fsm/.../state_reg -> dram_re`) is
your critical path, the delay is dominated by the artificial `set_output_delay`,
**not** real logic. Two remedies:

1. Lower the I/O delay budget (already 15%), or use the optional **core-only
   mode** in the XDC (false-path the I/O ports) to measure true reg2reg Fmax.
2. If a genuine reg2reg path fails (e.g. the PPU requant multiply), narrow the
   multiply operands to DSP-native widths (≤25×18) or add a pipeline stage.

## Methodology

```tcl
# after open_run impl_1
report_timing_summary -file timing_summary.txt
report_timing -setup -max_paths 10 -nworst 10 -sort_by slack -file critical_paths.txt
```

Check **WNS ≥ 0** (setup) and **WHS ≥ 0** (hold) in the summary.
