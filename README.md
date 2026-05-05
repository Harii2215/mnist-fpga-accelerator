# MNIST MLP Accelerator on FPGA (SystemVerilog)

An INT8-quantized 3-layer fully-connected (MLP) neural-network accelerator for
MNIST digit classification, written in SystemVerilog and targeted at the
**Xilinx Artix-7 AC701** evaluation board (`XC7A200T-2FBG676C`, speed grade -2).

> Verified in simulation and synthesized/implemented with **Vivado 2018.2**.

---

## Network

| Layer | Type            | In  | Out | Activation |
|-------|-----------------|-----|-----|------------|
| fc1   | Fully connected | 784 | 128 | ReLU       |
| fc2   | Fully connected | 128 | 64  | ReLU       |
| fc3   | Fully connected | 64  | 10  | (logits)   |

- **Datapath:** INT8 weights & activations, INT32 accumulators, Q0.16 requantization.
- **Compute:** weight-stationary systolic-style PE array (`ARRAY_SIZE = 16` MACs in parallel), output-tiled.
- **Memory:** on-chip BRAM/distributed SRAM for weights, biases, ping-pong activations, and output logits.

---

## Architecture

```
host ──► CSR (config_regs) ──► main_fsm ──► dma_loader ──► [WSRAM, BSRAM]
                                   │
                                   ▼
                          compute_layer
                    (pe_array ─► drain ─► ppu)
                                   │
                                   ▼
                       ASRAM A/B (ping-pong), OSRAM
```

See [`docs/architecture.md`](docs/architecture.md) for the full datapath and
control description.

---

## Repository layout

```
mnist_fpga/
├── rtl/                    # SystemVerilog source
│   ├── nn_pkg.sv           # shared params & types
│   ├── nn_params_auto.svh  # auto-generated network constants
│   ├── pe.sv               # single MAC processing element
│   ├── pe_array.sv         # N parallel PEs
│   ├── stagger_unit.sv     # pipeline-balancing shift register
│   ├── sram_sp.sv          # single-port SRAM (+ read-back peek port)
│   ├── ppu.sv              # bias + requant + ReLU + saturate
│   ├── drain_unit.sv       # accumulator serializer
│   ├── compute_layer.sv    # one FC layer controller + datapath
│   ├── config_regs.sv      # host CSR block
│   ├── dma_loader.sv       # DRAM -> on-chip SRAM loader
│   ├── main_fsm.sv         # top-level sequencer
│   └── nn_accel_top.sv     # top-level wrapper
├── python/                 # ML reference & quantization pipeline
│   ├── model.py            # 784-128-64-10 MLP
│   ├── dataset.py          # MNIST loaders
│   ├── train_model.py      # FP32 training (scaffold)
│   ├── inference.py        # FP32 inference + viz
│   ├── quantization.py     # PTQ + .mem dump + quant_params.json
│   ├── export_weights.py   # emits rtl/include/nn_params_auto.svh
│   ├── export_biases.py    # bias-only wrapper
│   ├── golden_model.py     # bit-exact INT8 reference
│   ├── accuracy_checker.py # INT8/FP32 accuracy + confusion matrix
│   ├── generate_test_vectors.py # per-digit test cases
│   ├── run_inference.py    # Python-vs-sim harness (scaffold)
│   └── requirements.txt
├── constraints/
│   └── nn_accel_timing.xdc # AC701 timing-only constraints
├── sim/
│   ├── dram_model.sv       # sim-only DRAM backing store
│   ├── tb_nn_accel_top.sv  # end-to-end self-checking testbench
│   ├── tb_pe.sv            # PE unit test
│   └── tb_ppu.sv           # PPU unit test
├── scripts/
│   └── build_vivado.tcl    # batch synth/impl/timing script
├── docs/
│   ├── architecture.md
│   ├── timing.md
│   └── CHANGELOG.md
├── LICENSE
└── README.md
```

---

## Quick start (Vivado 2018.2)

### GUI flow
1. Create a project targeting **`xc7a200tfbg676-2`**.
2. Add all files in `rtl/` as design sources; set **`nn_accel_top`** as top.
3. Add `constraints/nn_accel_timing.xdc` to the constraints set.
4. Add `sim/tb_nn_accel_top.sv` as a simulation source (top = `tb_nn_accel_top`).
5. Run **Simulation**, then **Synthesis → Implementation → Report Timing Summary**.

### Batch flow
```bash
vivado -mode batch -source scripts/build_vivado.tcl
```

---

## Timing

Constrained for a parameterized clock (default **100 MHz**) on the AC701 200 MHz
system oscillator (R3/P3, LVDS_25). See [`docs/timing.md`](docs/timing.md) for
the methodology, the timing-only constraint rationale, and Fmax notes.

---

## Status

- [x] RTL complete (all 13 modules)
- [x] Simulation passing
- [x] Synthesis clean
- [x] Implementation + timing closure
- [ ] On-board bring-up (board wrapper + pin LOCs) — _planned_

---

## License

MIT — see [`LICENSE`](LICENSE).
