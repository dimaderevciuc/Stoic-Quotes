// Shared by the host tests and the integration test: the exported assets and
// pipeline/data/golden/parity.json (written by `uv run stoic-embed parity`).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stoic_quotes/core/embedding/semantic_search.dart';

EmbeddingAssets loadAssetsFromDisk() {
  String text(String name) =>
      File('${EmbeddingAssets.dir}/$name').readAsStringSync();
  return EmbeddingAssets(
    config: text('config.json'),
    vocab: text('vocab.txt'),
    chars: text('chars.json'),
    quotes: ByteData.sublistView(
      File('${EmbeddingAssets.dir}/quotes.bin').readAsBytesSync(),
    ),
  );
}

class ParityCase {
  ParityCase.fromJson(Map<String, dynamic> json)
    : text = json['text'] as String,
      tokenIds = [for (final v in json['token_ids'] as List<dynamic>) v as int],
      top5Ids = [
        for (final e in json['top5'] as List<dynamic>)
          (e as Map<String, dynamic>)['id'] as String,
      ],
      top5Scores = [
        for (final e in json['top5'] as List<dynamic>)
          ((e as Map<String, dynamic>)['score'] as num).toDouble(),
      ],
      query = Float32List.fromList([
        for (final v in json['query'] as List<dynamic>) (v as num).toDouble(),
      ]);

  final String text;
  final List<int> tokenIds;
  final List<String> top5Ids;
  final List<double> top5Scores;
  final Float32List query;

  String get label => text.length > 40 ? '${text.substring(0, 40)}...' : text;
}

List<ParityCase> loadParityCases() => [
  for (final c in jsonDecode(
    File('pipeline/data/golden/parity.json').readAsStringSync(),
  ) as List<dynamic>)
    ParityCase.fromJson(c as Map<String, dynamic>),
];
