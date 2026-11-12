/// Row-quantized int8 matrix as written by the pipeline (`embed.py write_matrix`).
///
/// Layout, little endian: "SQE1", u32 rows, u32 dim, f32 scales[rows], i8 data[rows*dim].
/// Row i is approximately data[i] * scales[i].
library;

import 'dart:typed_data';

class Int8Matrix {
  Int8Matrix._(this.rows, this.dim, this.scales, this.data);

  factory Int8Matrix.fromBytes(ByteData bytes) {
    const magic = [0x53, 0x51, 0x45, 0x31]; // "SQE1"
    if (bytes.lengthInBytes < 12) {
      throw const FormatException('matrix file too short');
    }
    for (var i = 0; i < 4; i++) {
      if (bytes.getUint8(i) != magic[i]) {
        throw const FormatException('not an SQE1 matrix');
      }
    }
    final rows = bytes.getUint32(4, Endian.little);
    final dim = bytes.getUint32(8, Endian.little);
    final expected = 12 + 4 * rows + rows * dim;
    if (bytes.lengthInBytes != expected) {
      throw FormatException(
        'matrix size ${bytes.lengthInBytes}, expected $expected',
      );
    }
    final scales = Float32List(rows);
    for (var i = 0; i < rows; i++) {
      scales[i] = bytes.getFloat32(12 + 4 * i, Endian.little);
    }
    // A view, not a copy: the token matrix is several MB.
    final data = bytes.buffer.asInt8List(
      bytes.offsetInBytes + 12 + 4 * rows,
      rows * dim,
    );
    return Int8Matrix._(rows, dim, scales, data);
  }

  final int rows;
  final int dim;
  final Float32List scales;
  final Int8List data;
}
