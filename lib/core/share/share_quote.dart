/// Shares a quote card as a PNG image (with its citation) through the share sheet.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../content/quote.dart';

Future<void> shareQuoteImage(GlobalKey boundaryKey, Quote quote) async {
  final boundary = boundaryKey.currentContext?.findRenderObject();
  final text = '"${quote.text}"\n${quote.author}, ${quote.sourceLine}';
  if (boundary is! RenderRepaintBoundary) {
    await SharePlus.instance.share(ShareParams(text: text));
    return;
  }
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) {
    await SharePlus.instance.share(ShareParams(text: text));
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [
        XFile.fromData(
          bytes.buffer.asUint8List(),
          mimeType: 'image/png',
          name: 'stoic-quote-${quote.id}.png',
        ),
      ],
    ),
  );
}
