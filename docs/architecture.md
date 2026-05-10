# Architecture

## Overview

The accelerator runs a 3-layer INT8 MLP for MNIST. A host programs control
registers (CSR), the `main_fsm` orchestrates DMA loads and per-layer compute,
and results land in an output SRAM that the host reads back.

## Datapath

```
                 ┌───────────────┐
   host CSR ────►│  config_regs  │  start / soft_reset / ptrs / IRQ
                 └──────┬────────┘
                        │
                 ┌──────▼────────┐      ┌──────────────┐
                 │   main_fsm    │─────►│  dma_loader  │──► WSRAM / BSRAM / ASRAM
                 └──────┬────────┘      └──────────────┘
                        │ cl_start / layer descriptor
                 ┌──────▼─────────────────────────────────┐
                 │            compute_layer                │
                 │  ┌─────────┐  ┌────────┐  ┌──────────┐  │
   ASRAM(A/B) ──►│  │pe_array │─►│ drain  │─►│   ppu    │──┼──► ASRAM(A/B)/OSRAM
   WSRAM ───────►│  │ (N MACs)│  │ (serdes│  │bias+req. │  │
   BSRAM ───────►│  └─────────┘  └────────┘  │ReLU+sat) │  │
                 │                            └──────────┘  │
                 └─────────────────────────────────────────┘
```

## Modules

| Module          | Role |
|-----------------|------|
| `nn_pkg`        | Shared parameters (sizes, widths, memory depths) and the layer-descriptor type. |
| `nn_params_auto`| Auto-generated network constants (`*.svh`, from `export_weights.py`). |
| `pe`            | Single signed INT8×INT8 MAC with synchronous clear/accumulate. |
| `pe_array`      | `ARRAY_SIZE` parallel PEs sharing a broadcast activation, each fed its own weight. |
| `stagger_unit`  | Parameterized shift-register for pipeline alignment (DELAY=0 bypass). |
| `sram_sp`       | Single-port SRAM; optional synthesizable read-back (`peek_flat`). |
| `ppu`           | 3-stage post-processing: bias add → requant multiply → arithmetic shift + ReLU + INT8 saturate. |
| `drain_unit`    | Serializes a tile's N accumulators into a 1/cycle stream + bias address. |
| `compute_layer` | Per-layer controller: output tiling, weight-stationary streaming, drain, PPU, write-back. |
| `config_regs`   | Host CSR: control, status (busy/done), input/output pointers, IRQ, cycle counter. |
| `dma_loader`    | Burst loader from a flat DRAM model into the selected on-chip SRAM. |
| `main_fsm`      | Top sequencer: load weights → bias → input, then fc1 → fc2 → fc3, then done. |
| `nn_accel_top`  | Top-level wrapper connecting everything + DRAM/CSR/readback ports. |

## Dataflow choice: weight-stationary

For one output tile of `N` neurons, the activation vector is streamed one
element per cycle and broadcast to all `N` PEs; each PE holds its own weight for
that (tile, k). After `IN_SIZE` cycles, all `N` accumulators hold the tile's dot
products. FC layers are bandwidth-bound on weights, so streaming activations and
keeping weights local minimizes weight traffic.

## Memory map (flat DRAM model used by the testbench)

| Region          | Base address | Contents |
|-----------------|--------------|----------|
| Weights         | `0x0000_0000`| Packed INT8 weights, `WSRAM_DEPTH` words |
| Biases          | `0x0001_0000`| INT32 biases (all layers concatenated) |
| Input image     | `input_ptr`  | `INPUT_SIZE` INT8 bytes |

## Quantization

`y = clip( ((acc + bias) * M_q) >>> FRACTION_BITS , -128, 127 )`, with optional
ReLU before saturation. `M_q` is a Q0.16 per-layer multiplier emitted by the
weight-export tooling into `nn_params_auto.svh`.
