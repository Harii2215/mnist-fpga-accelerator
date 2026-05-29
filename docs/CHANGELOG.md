# Changelog

All notable changes to this project are documented here.

## [Unreleased]
- On-board bring-up wrapper (`ac701_top.sv`) + pin-LOC XDC (planned).

## v0.5 — Timing closure
- Added timing-only XDC for AC701 (`xc7a200tfbg676-2`).
- Reduced I/O delay budgets; documented core-only Fmax methodology.

## v0.4 — Synthesis fixes
- Replaced hierarchical OSRAM read-back with a synthesizable `peek_flat` port.
- Fixed `parameter string` (Vivado 8-27) and include-guard in `nn_params_auto.svh`.
- Reconciled top-level port names with `main_fsm` / `compute_layer`.

## v0.4 — Verification
- `dram_model.sv` sim backing store.
- Unit testbenches: `tb_pe.sv`, `tb_ppu.sv`.
- End-to-end self-checking `tb_nn_accel_top.sv` (RTL vs Python golden).

## v0.3 — RTL
- Compute primitives, post-processing, layer controller, top-level integration.

## v0.2 — Python pipeline
- MLP model, MNIST loaders, FP32 training/inference.
- Post-training INT8 quantization, bit-exact golden model, accuracy checker.
- Weight/bias exporters, SV header generation, and test-vector generator.

## v0.1 — Scaffolding
- Repo structure, license, architecture docs.
