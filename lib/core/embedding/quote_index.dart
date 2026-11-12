/// Brute force cosine search over the precomputed quote vectors.
///
/// A few hundred quotes times a few hundred dimensions is well under a
/// millisecond, so no approximate index is needed.
library;

import 'dart:typed_data';

import 'int8_matrix.dart';

class QuoteHit {
  const QuoteHit(this.id, this.score);

  final String id;

  /// Cosine similarity, about -1 to 1 (both sides are unit vectors).
  final double score;

  @override
  String toString() => 'QuoteHit($id, ${score.toStringAsFixed(4)})';
}

class QuoteIndex {
  QuoteIndex({required this.ids, required this.vectors}) {
    if (ids.length != vectors.rows) {
      throw ArgumentError('${ids.length} ids for ${vectors.rows} vectors');
    }
  }

  final List<String> ids;
  final Int8Matrix vectors;

  List<QuoteHit> search(Float32List query, {int k = 5}) {
    if (query.length != vectors.dim) {
      throw ArgumentError(
        'query has ${query.length} dims, index has ${vectors.dim}',
      );
    }
    final dim = vectors.dim;
    final scores = Float64List(vectors.rows);
    for (var i = 0; i < vectors.rows; i++) {
      final offset = i * dim;
      var dot = 0.0;
      for (var j = 0; j < dim; j++) {
        dot += vectors.data[offset + j] * query[j];
      }
      scores[i] = dot * vectors.scales[i];
    }
    // Ties keep index order, like numpy's stable argsort in the pipeline.
    final order = List<int>.generate(vectors.rows, (i) => i)
      ..sort((a, b) {
        final c = scores[b].compareTo(scores[a]);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final i in order.take(k)) QuoteHit(ids[i], scores[i])];
  }
}
