import 'package:flutter/painting.dart';

class IRect {
  final int left;
  final int right;
  final int top;
  final int bottom;

  IRect({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  @override
  String toString() {
    return "[$left, $right, $top, $bottom]";
  }
}

class ISize {
  final int width;
  final int height;

  const ISize(this.width, this.height);

  Size toSize() => Size(width.toDouble(), height.toDouble());
}
