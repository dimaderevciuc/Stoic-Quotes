/// Mean pooling and L2 normalization of the model's per-token outputs.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// [hidden] is the flattened [seqLen, dim] output for one sentence without
/// padding, so every position counts (same as the attention masked mean).
Float32List meanPoolNormalize(List<double> hidden, int seqLen, int dim) {
  if (hidden.length != seqLen * dim) {
    throw ArgumentError(
      'hidden has ${hidden.length} values, expected ${seqLen * dim}',
    );
  }
  final sum = Float64List(dim);
  for (var t = 0; t < seqLen; t++) {
    final offset = t * dim;
    for (var j = 0; j < dim; j++) {
      sum[j] += hidden[offset + j];
    }
  }
  // The mean's 1/seqLen cancels in the normalization, so only the norm is needed.
  var norm = 0.0;
  for (var j = 0; j < dim; j++) {
    norm += sum[j] * sum[j];
  }
  norm = math.sqrt(norm);
  final out = Float32List(dim);
  if (norm == 0) return out;
  for (var j = 0; j < dim; j++) {
    out[j] = sum[j] / norm;
  }
  return out;
}
