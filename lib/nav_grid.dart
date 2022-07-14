import 'dart:typed_data';

import 'package:astar/astar_2d.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart';

import 'geometry.dart';

IRect _getBoundingIntegerRect(Rect rect) {
  return IRect(
    left: rect.left.floor(),
    right: rect.right.floor(),
    top: rect.top.floor(),
    bottom: rect.bottom.floor(),
  );
}

Location _getLocation(Offset offset) {
  return Location(offset.dx.toInt(), offset.dy.toInt());
}

class NavGrid {
  static const worldSize = ISize(100, 100);

  final Grid barriers = Grid.zeroed(worldSize);

  bool isPassable(int x, y) => !(barriers.get(x, y) ?? true);

  Iterable<Offset> findPath(Offset start, Offset end) {
    final pathFinder =
        PathFinder2D(isPassable: isPassable, allowDiagonal: false);
    final path =
        pathFinder.findPath(_getLocation(start), _getLocation(end)) ?? [];
    return path.map((e) => Offset(e.x.toDouble(), e.y.toDouble()));
  }

  void markNotPassable(Rect bounds) {
    final rect = _getBoundingIntegerRect(bounds);
    for (var x = rect.left; x <= rect.right; ++x) {
      for (var y = rect.top; y <= rect.bottom; ++y) {
        barriers.set(x, y, true);
      }
    }
  }
}

class Grid {
  final ISize size;
  final Uint8List _data;

  Grid.zeroed(this.size) : _data = Uint8List(size.width * size.height);

  int get width => size.width;
  int get height => size.height;

  int _getIndex(int x, int y) => x + y * width;
  int _encoded(bool value) => value ? 1 : 0;
  bool _decode(int value) => value != 0;

  void set(int x, int y, bool value) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }
    _data[_getIndex(x, y)] = _encoded(value);
  }

  bool? get(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return null;
    }
    return _decode(_data[_getIndex(x, y)]);
  }
}
