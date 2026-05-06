# Python Reference & Quantization Pipeline

FP32 training → post-training INT8 quantization → bit-exact golden model →
memory-init (`.mem`) generation → test-vector generation for RTL verification.

## Install
```bash
cd python
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Files

| File                      | Role |
|---------------------------|------|
| `model.py`                | The 784-128-64-10 MLP definition. |
| `dataset.py`              | MNIST loaders + normalization. |
| `train_model.py`          | FP32 training → `results/mlp_mnist_best.pt`. |
| `inference.py`            | FP32 inference + sample visualization grid. |
| `quantization.py`         | PTQ: scales, INT8/INT32 params, `quant_layer` reference, `.mem` dumps, `quant_params.json`. |
| `export_weights.py`       | Runs quantization + emits `rtl/include/nn_params_auto.svh`. |
| `export_biases.py`        | Bias-only convenience wrapper over `export_weights.py`. |
| `golden_model.py`         | Bit-exact INT8 reference (matches the RTL). |
| `accuracy_checker.py`     | INT8 (and optional FP32) accuracy + confusion matrix. |
| `generate_test_vectors.py`| Per-digit test cases: `input.mem`, `golden_output.mem`, previews. |
| `run_inference.py`        | End-to-end harness comparing Python vs Icarus sim logs. |

## Typical flow
```bash
python train_model.py                 # 1) train FP32 model
python quantization.py                # 2) PTQ + emit .mem + quant_params.json
python export_weights.py              # 3) emit nn_params_auto.svh for the RTL
python accuracy_checker.py            # 4) report INT8 accuracy
python generate_test_vectors.py       # 5) make verification vectors
```

> Note: `train_model.py` and `run_inference.py` are trimmed scaffolds in this
> public repo (interface only). The remaining modules are complete and runnable.
