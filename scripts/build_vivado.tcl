# ===========================================================================
# build_vivado.tcl -- batch synth + impl + timing for the MNIST MLP accelerator
#
# Usage:
#   vivado -mode batch -source scripts/build_vivado.tcl
#
# Run this from the repository root (the directory that contains rtl/).
# ===========================================================================

set PART       xc7a200tfbg676-2
set TOP        nn_accel_top
set OUTDIR     build
set RTLDIR     rtl
set XDC        constraints/nn_accel_timing.xdc

file mkdir $OUTDIR

# ---- read SYNTHESIS sources (package first) ----
# NOTE: sim/ files (testbenches + dram_model) are NOT read here -- they are
# simulation-only. Run them in xsim/Icarus separately.
read_verilog -sv $RTLDIR/nn_pkg.sv
read_verilog -sv [glob $RTLDIR/*.sv]
# header is included via `include in nn_accel_top.sv; make it visible:
set_property include_dirs $RTLDIR [current_fileset]

read_xdc $XDC

# ---- synthesis ----
synth_design -top $TOP -part $PART
write_checkpoint -force $OUTDIR/post_synth.dcp
report_timing_summary -file $OUTDIR/post_synth_timing.rpt
report_utilization     -file $OUTDIR/post_synth_util.rpt

# ---- implementation ----
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force $OUTDIR/post_route.dcp

# ---- reports ----
report_timing_summary -file $OUTDIR/post_route_timing.rpt
report_timing -setup -max_paths 10 -nworst 10 -sort_by slack \
              -file $OUTDIR/critical_paths.rpt
report_utilization -file $OUTDIR/post_route_util.rpt

puts "==============================================================="
puts " Build complete. Reports written to $OUTDIR/"
puts "   - post_route_timing.rpt   (check WNS/WHS here)"
puts "   - critical_paths.rpt"
puts "   - post_route_util.rpt"
puts "==============================================================="
