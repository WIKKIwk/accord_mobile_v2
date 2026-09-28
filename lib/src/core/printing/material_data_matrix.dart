import 'package:barcode/barcode.dart';

/// ECC 200 black rectangles in a unit square, without an internal margin.
/// Native printers reuse this pattern for each copy at the chosen dot size.
/// The label's surrounding white space supplies the quiet zone.
List<List<double>> materialDataMatrixBars(String epc) {
  final elements = Barcode.dataMatrix().make(
    epc,
    width: 1,
    height: 1,
    drawText: false,
  );
  return [
    for (final bar in elements.whereType<BarcodeBar>())
      if (bar.black)
        [
          _edge(bar.left),
          _edge(bar.top),
          _edge(bar.left + bar.width),
          _edge(bar.top + bar.height),
        ],
  ];
}

// Canonicalize shared edges before native dot rounding: e.g. top + height
// and the next row's top can otherwise fall on opposite sides of a half-dot.
double _edge(double value) =>
    double.parse(value.clamp(0.0, 1.0).toStringAsFixed(12));
