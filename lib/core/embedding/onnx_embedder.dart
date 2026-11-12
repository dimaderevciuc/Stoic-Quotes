/// Runs the sentence transformer with ONNX Runtime (flutter_onnxruntime plugin).
library;

import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'pooling.dart';
import 'semantic_search.dart';

class OnnxEmbedder implements TextEmbedder {
  OnnxEmbedder._(this._session, this.dim);

  /// [assetKey] must change whenever the model changes: the plugin caches the
  /// extracted file by name (the export puts a hash in it).
  static Future<OnnxEmbedder> fromAsset(
    String assetKey, {
    required int dim,
  }) async {
    final session = await OnnxRuntime().createSessionFromAsset(
      assetKey,
      // Two threads: fast enough for one short sentence, and leaves the UI room.
      options: OrtSessionOptions(intraOpNumThreads: 2),
    );
    return OnnxEmbedder._(session, dim);
  }

  final OrtSession _session;
  final int dim;

  @override
  Future<Float32List> embedIds(List<int> ids) async {
    final shape = [1, ids.length];
    final inputs = {
      'input_ids': await OrtValue.fromList(Int64List.fromList(ids), shape),
      'attention_mask': await OrtValue.fromList(
        Int64List(ids.length)..fillRange(0, ids.length, 1),
        shape,
      ),
      'token_type_ids': await OrtValue.fromList(Int64List(ids.length), shape),
    };
    Map<String, OrtValue>? outputs;
    try {
      outputs = await _session.run(inputs);
      final hidden = outputs['last_hidden_state'];
      if (hidden == null) {
        throw StateError('model has no last_hidden_state output');
      }
      final flat = await hidden.asFlattenedList();
      return meanPoolNormalize(
        [for (final v in flat) (v as num).toDouble()],
        ids.length,
        dim,
      );
    } finally {
      // Tensors live in native memory until released.
      for (final v in inputs.values) {
        await v.dispose();
      }
      for (final v in outputs?.values ?? const <OrtValue>[]) {
        await v.dispose();
      }
    }
  }

  Future<void> close() => _session.close();
}
