import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tower Defense',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GameState _gameState = GameState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tower Defense"),
      ),
      body: Center(
        child: GameView(gameState: _gameState),
      ),
    );
  }
}

class GameView extends StatelessWidget {
  const GameView({super.key, required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: GameWidget(game: gameState),
    );
  }
}

class Objective extends RectangleComponent {
  static final _paint = Paint()..color = Colors.orange.shade400;

  Objective() {
    width = 2;
    height = 2;
    add(CircleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(Offset.zero, width / 2, _paint);
  }
}

class Barrier extends RectangleComponent {
  static final _paint = Paint()..color = Colors.blue.shade400;

  Barrier() {
    width = 2;
    height = 2;
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), _paint);
  }
}

class Attacker extends RectangleComponent with HasGameRef<GameState> {
  static final _paint = Paint()..color = Colors.red.shade400;

  final double _speed = 5.0;

  Attacker() {
    width = 1;
    height = 1;
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    final objective = gameRef.objective;
    final delta = objective.center - center;
    center += delta.normalized() * _speed * dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(Offset.zero, width / 2, _paint);
  }
}

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
}

IRect getBoundingIntegerRect(Rect rect) {
  return IRect(
    left: rect.left.floor(),
    right: rect.right.ceil(),
    top: rect.top.floor(),
    bottom: rect.bottom.ceil(),
  );
}

class NavGrid {
  static const worldSize = ISize(100, 100);

  final _passable = Grid<bool>.filled(worldSize, (position) => true);

  void markNotPassable(Rect bounds) {
    final rect = getBoundingIntegerRect(bounds);
    for (var x = rect.left; x <= rect.right; ++x) {
      for (var y = rect.top; y <= rect.bottom; ++y) {
        _passable.set(GridPosition(x, y), false);
      }
    }
  }
}

class GridPosition {
  final int x;
  final int y;

  const GridPosition(this.x, this.y);

  static const zero = GridPosition(0, 0);

  @override
  bool operator ==(other) {
    if (other is! GridPosition) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

class ISize {
  final int width;
  final int height;

  const ISize(this.width, this.height);

  Size toSize() => Size(width.toDouble(), height.toDouble());
}

class Grid<T> {
  final List<List<T>> _cells;

  const Grid(this._cells);

  Grid.filled(ISize size, T Function(GridPosition position) create)
      : _cells = List.generate(
            size.height,
            (y) =>
                List.generate(size.width, (x) => create(GridPosition(x, y))));

  ISize get size => ISize(width, height);
  int get width => _cells.first.length;
  int get height => _cells.length;

  void set(GridPosition position, T cell) {
    if (position.y < 0 || position.y >= _cells.length) {
      throw ArgumentError.value(position);
    }
    final row = _cells[position.y];
    if (position.x < 0 || position.x >= row.length) {
      throw ArgumentError.value(position);
    }
    row[position.x] = cell;
  }

  T? get(GridPosition position) {
    if (position.x < 0 || position.x >= width) {
      return null;
    }
    if (position.y < 0 || position.y >= height) {
      return null;
    }
    return _get(position);
  }

  T _get(GridPosition position) {
    final row = _cells[position.y];
    return row[position.x];
  }

  Iterable<GridPosition> get allPositions sync* {
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        yield GridPosition(x, y);
      }
    }
  }

  Iterable<T> get cells => allPositions.map((position) => _get(position));

  Iterable<List<T>> get cellsByRow => _cells;
}

class GameState extends FlameGame {
  late Objective objective;
  final NavGrid grid = NavGrid();

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(Vector2.all(100.0));
    objective = Objective()
      ..position = Vector2(size.x / 2, size.y - 1)
      ..anchor = Anchor.bottomCenter;
    add(objective);
    addBarriers();
    startWave();
  }

  Iterable<Vector2> _generateAttackerPositions(int count) sync* {
    for (int i = 0; i < count; i++) {
      yield Vector2(math.Random().nextDouble() * size.x, 1);
    }
  }

  Iterable<Vector2> _generateBarrierPositions(int count) sync* {
    for (int i = 0; i < count; i++) {
      yield Vector2(
        math.Random().nextDouble() * size.x,
        math.Random().nextDouble() * size.y,
      );
    }
  }

  void addBarriers() {
    final barriers = [
      for (var position in _generateBarrierPositions(100))
        Barrier()
          ..position = position
          ..anchor = Anchor.center,
    ];
    for (var barrier in barriers) {
      grid.markNotPassable(barrier.size.toRect());
    }
    addAll(barriers);
  }

  void startWave() {
    addAll([
      for (var position in _generateAttackerPositions(10))
        Attacker()
          ..position = position
          ..anchor = Anchor.center,
    ]);
  }
}
