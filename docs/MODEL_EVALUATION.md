# Dhikr Counter — Local Model Evaluation Plan

## Purpose

Choose the recognition stack based on evidence rather than brand, model size alone, or generic ASR benchmarks.

## Candidate policy

Start by researching compact, locally executable Arabic-capable models compatible with Flutter/mobile.

sherpa-onnx is one candidate ecosystem because it supports offline/on-device ASR and has Flutter/platform examples. It is not automatically the final choice.

Other local ONNX/runtime options may be evaluated if they have better evidence on mobile Arabic phrase recognition.

## Evaluation table

Create and maintain this table in `docs/MODEL_EVALUATION_RESULTS.md` during implementation.

| Candidate | Arabic | Streaming | Android | iOS | Quantized | Size | License | Phrase Recall | False Positives | Latency | CPU | RAM | Battery | Decision |
|---|---|---|---|---|---|---:|---|---:|---:|---:|---:|---:|---:|---|
| Candidate A | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Candidate B | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## Required tests

Use permissioned test audio or recordings made by consenting testers.

### Phrase accuracy

Test supported dhikr at:

- slow pace
- natural pace
- rapid pace

### Repetition accuracy

Ground truth:

- 1 repetition
- 2 repetitions
- 4 repetitions
- 10 repetitions

Compare exact count.

### Robustness

Test:

- low volume
- normal volume
- fan noise
- street noise
- background conversation
- different microphones
- different speakers

## Primary metrics

The primary metric is **dhikr repetition-count accuracy**, not generic word error rate alone.

For each test session:

```text
ground_truth = N
detected = D

count_error = D - N
absolute_count_error = |D - N|
```

Track:

- precision of accepted count events
- recall of true repetitions
- false-positive rate
- absolute count error
- latency
- peak RAM
- average CPU
- battery behavior

## Model size is not the only constraint

A smaller model that misses one out of five real repetitions is not automatically preferable to a somewhat larger model that gives a much more dependable count.

Conversely, a multi-gigabyte model is probably inappropriate for this product if a much smaller model can provide adequate phrase-level accuracy.

## Licensing gate

Record the exact model source and license.

Do not assume that the software library's license automatically covers the model weights.

The release package must be legally redistributable under its actual licenses and attribution requirements.

## Final decision format

Once testing is complete, write:

```text
Selected engine/model:
Exact version/date:
Runtime:
Model size:
Quantization:
License:
Why selected:
Known limitations:
Minimum tested device:
Maximum observed RAM:
Typical CPU:
Median latency:
Repetition recall:
False-positive rate:
```
