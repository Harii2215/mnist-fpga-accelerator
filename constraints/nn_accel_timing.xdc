# =============================================================================
# nn_accel_timing.xdc  --  TIMING-ONLY constraints for nn_accel_top
#
# Board : Xilinx Artix-7 AC701 Evaluation Board
# FPGA  : XC7A200T-2FBG676C, speed grade -2
#
# PURPOSE
#   This file constrains TIMING only (clock + I/O budgets + async paths) so you
#   can run synth/impl and read a meaningful timing report. It deliberately does
#   NOT assign physical PACKAGE_PIN/IOSTANDARD locations, because nn_accel_top's
#   interface (CSR bus, 128-bit DRAM port, 80-bit logits) is an internal/SoC
#   interface that is not meant to be wired to AC701 device pins directly.
#   (For real hardware bring-up you'd add a board wrapper + a pin-LOC XDC.)
#
# HOW TO USE
#   - Add this XDC to your Vivado project (Constraints set).
#   - Set nn_accel_top as the top module.
#   - Run Synthesis, then Implementation, then open the Timing Summary report
#     (Reports -> Timing -> Report Timing Summary) and check WNS/WHS/TNS.
#
# NOTE on device pins
#   When no pins are assigned, Vivado will warn that ports are unconstrained
#   (placement may fail at the *implementation* DRC for unplaced I/O). For a
#   pure timing check after SYNTHESIS this is fine. If you want implementation
#   to complete without pin LOCs, either:
#     (a) keep this as an OOC (out-of-context) synthesis run, or
#     (b) let Vivado auto-place I/O:  set_property BITSTREAM... not needed; just
#         run impl and ignore the unplaced-port DRC, OR add the AC701 wrapper.
# =============================================================================

# -----------------------------------------------------------------------------
# 1) PRIMARY CLOCK
# -----------------------------------------------------------------------------
# The AC701 fixed system oscillator is 200 MHz (SYSCLK_P=R3 / SYSCLK_N=P3,
# LVDS_25, bank 34). nn_accel_top takes a single-ended 'clk', so for the
# timing model we declare the clock period directly on the 'clk' port.
#
# >>>> SET YOUR TARGET FREQUENCY HERE <<<<
#   Period is in ns. 5.000 ns = 200 MHz (the raw board clock).
#   If your design will be driven from an MMCM-divided clock, set the period to
#   your real target (e.g. 10.000 = 100 MHz, 8.000 = 125 MHz).
set CLK_PERIOD_NS 10.000
create_clock -name sys_clk -period $CLK_PERIOD_NS [get_ports clk]

# Clock uncertainty / jitter budget (input jitter of the 200 MHz osc is ~50 ppm;
# this small system uncertainty gives margin in the report).
set_clock_uncertainty 0.100 [get_clocks sys_clk]

# -----------------------------------------------------------------------------
# 2) INPUT / OUTPUT DELAY BUDGETS (synchronous I/O timing)
# -----------------------------------------------------------------------------
# We budget I/O conservatively. These ports form an INTERNAL SoC interface
# (CSR bus, DRAM port, logits) -- they are NOT tight external-device pins -- so
# large I/O delays here are artificial and will create false setup failures on
# register->port paths (e.g. u_fsm state -> dram_re). Keep them small.
# If you later attach a real external device with a known spec, raise these.
set IN_DELAY  [expr {0.15 * $CLK_PERIOD_NS}]
set OUT_DELAY [expr {0.15 * $CLK_PERIOD_NS}]

# ---- Synchronous INPUTS (everything except clk and the async reset) ----
set sync_inputs [get_ports {reg_we reg_addr[*] reg_wdata[*] dram_rdata[*]}]
set_input_delay  -clock sys_clk $IN_DELAY  $sync_inputs

# ---- Synchronous OUTPUTS ----
set sync_outputs [get_ports {reg_rdata[*] irq \
                             dram_re dram_addr[*] \
                             out_logits_packed[*] out_valid}]
set_output_delay -clock sys_clk $OUT_DELAY $sync_outputs

# -----------------------------------------------------------------------------
# 3) ASYNCHRONOUS RESET
# -----------------------------------------------------------------------------
# rst_n is an asynchronous, active-low reset (used in 'negedge rst_n' in the
# RTL). It is not timed against sys_clk; cut it so it doesn't create false
# critical paths or unconstrained-input warnings.
set_false_path -from [get_ports rst_n]

# If you later synchronize rst_n internally and want it timed, remove the line
# above and add a proper set_input_delay instead.

# -----------------------------------------------------------------------------
# 4) (OPTIONAL) PHYSICAL PIN/IOSTANDARD FOR THE CLOCK ONLY
# -----------------------------------------------------------------------------
# If you DO drive nn_accel_top.clk straight from the board's single-ended view
# of the system clock and want implementation to place that one pin, uncomment.
# (The real board clock is a DIFFERENTIAL LVDS pair on R3/P3 -- a single-ended
#  'clk' port cannot map to it directly without an IBUFDS in a wrapper, so this
#  is left commented. Use the board wrapper for real hardware.)
#
# set_property PACKAGE_PIN R3       [get_ports clk]
# set_property IOSTANDARD  LVDS_25  [get_ports clk]

# -----------------------------------------------------------------------------
# 5) (OPTIONAL) "CORE-ONLY" MODE  --  measure true register-to-register Fmax
# -----------------------------------------------------------------------------
# nn_accel_top's ports are an INTERNAL interface, so external I/O timing on them
# is artificial. The number that actually limits your hardware is the
# register-to-register (reg2reg) path inside the core.
#
# If a register->port path (e.g. u_fsm/FSM_sequential_state_reg -> dram_re) is
# your reported critical path, that delay is dominated by the artificial
# set_output_delay above, NOT by real logic. To measure the genuine core Fmax,
# UNCOMMENT the block below to remove I/O timing entirely and let the tool
# report only reg2reg paths.
#
# set_false_path -to   [get_ports {reg_rdata[*] irq dram_re dram_addr[*] \
#                                  out_logits_packed[*] out_valid}]
# set_false_path -from [get_ports {reg_we reg_addr[*] reg_wdata[*] dram_rdata[*]}]
#
# (Leave section 2's set_input_delay/set_output_delay in place; the false_paths
#  above override them for these specific ports. Or simply comment out section 2.)

# =============================================================================
# End of timing-only constraints
# =============================================================================
