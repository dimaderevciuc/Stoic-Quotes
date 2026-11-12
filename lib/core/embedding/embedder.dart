/// Model2Vec sentence embedding: mean of the token vectors, then L2 normalize.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'int8_matrix.dart';
import 'tokenizer.dart';

class StaticEmbedder {
  StaticEmbedder({required this.tokenizer, required this.tokens});

  final WordPieceTokenizer tokenizer;
  final Int8Matrix tokens;

  int get dim => tokens.dim;

  /// Unit vector for [text]; all zeros when no known token is left (empty input).
  Float32List embed(String text) => embedIds(tokenizer.tokenize(text));

  Float32List embedIds(List<int> ids) {
    final dim = tokens.dim;
    final sum = Float64List(dim);
    for (final id in ids) {
      final scale = tokens.scales[id];
      final offset = id * dim;
      for (var j = 0; j < dim; j++) {
        sum[j] += tokens.data[offset + j] * scale;
      }
    }
    final out = Float32List(dim);
    if (ids.isEmpty) return out;
    // The mean's 1/n cancels in the normalization, so only the norm is needed.
    var norm = 0.0;
    for (var j = 0; j < dim; j++) {
      norm += sum[j] * sum[j];
    }
    norm = math.sqrt(norm);
    if (norm == 0) return out;
    for (var j = 0; j < dim; j++) {
      out[j] = sum[j] / norm;
    }
    return out;
  }
}
