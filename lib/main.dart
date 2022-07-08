import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/extensions.dart';

import 'package:a_star/a_star.dart';

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

class Barrier extends RectangleComponent with HasGameRef<GameState> {
  static final _paint = Paint()..color = Colors.blue.shade400;

  Barrier() {
    width = 2;
    height = 2;
    add(RectangleHitbox());
  }

  @override
  void onMount() {
    super.onMount();
    gameRef.grid
        .markNotPassable(Rect.fromLTWH(position.x, position.y, size.x, size.y));
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

  double closeEnough = 0.1;
  List<Offset> waypoints = [];

  Attacker() {
    width = 1;
    height = 1;
    add(CircleHitbox());
  }

  @override
  void onMount() {
    moveTo(gameRef.objective.center.toOffset());
  }

  void moveTo(Offset target) {
    waypoints = gameRef.grid.findPath(center.toOffset(), target).toList();
  }

  Vector2? getNextWaypoint() {
    if (waypoints.isEmpty) {
      return null;
    }
    return waypoints.first.toVector2();
  }

  @override
  void update(double dt) {
    var objective = getNextWaypoint();
    if (objective == null) {
      return;
    }
    if (center.distanceTo(objective) < closeEnough) {
      waypoints.removeAt(0);
      objective = getNextWaypoint();
      if (objective == null) {
        return;
      }
    }
    final delta = objective - center;
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

  @override
  String toString() {
    return "[$left, $right, $top, $bottom]";
  }
}

IRect getBoundingIntegerRect(Rect rect) {
  return IRect(
    left: rect.left.floor(),
    right: rect.right.ceil(),
    top: rect.top.floor(),
    bottom: rect.bottom.ceil(),
  );
}

class TerrainTile extends Object with Node<TerrainTile> {
  final int x;
  final int y;

  TerrainTile(this.x, this.y);

  TerrainTile.fromOffset(Offset offset)
      : x = offset.dx.floor(),
        y = offset.dy.floor();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerrainTile &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

class TerrainMap implements Graph<TerrainTile> {
  final Grid<bool> _barriers;

  TerrainMap(this._barriers);

  @override
  Iterable<TerrainTile> get allNodes {
    return _barriers.allPositions
        .where((e) => !_barriers.get(e)!)
        .map((e) => TerrainTile(e.x, e.y));
  }

  @override
  num getDistance(TerrainTile a, TerrainTile b) =>
      (b.x - a.x).abs() + (b.y - a.y).abs();

  @override
  num getHeuristicDistance(TerrainTile a, TerrainTile b) => getDistance(a, b);

  @override
  Iterable<TerrainTile> getNeighboursOf(TerrainTile node) {
    final neighbours = <TerrainTile>[];
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        if (i == 0 && j == 0) {
          continue;
        }
        if (i != 0 && j != 0) {
          continue;
        }
        final x = node.x + i;
        final y = node.y + j;
        final isObstacle = _barriers.get(GridPosition(x, y));
        if (isObstacle == null || isObstacle) {
          continue;
        }
        neighbours.add(TerrainTile(x, y));
      }
    }
    return neighbours;
  }
}

class NavGrid {
  static const worldSize = ISize(100, 100);

  final _barriers = Grid<bool>.filled(worldSize, (position) => false);

  Iterable<Offset> findPath(Offset start, Offset end) {
    var map = TerrainMap(_barriers);
    var pathFinder = AStar(map);
    return pathFinder
        .findPathSync(
            TerrainTile.fromOffset(start), TerrainTile.fromOffset(end))
        .map((e) => Offset(e.x.toDouble(), e.y.toDouble()));
  }

  void markNotPassable(Rect bounds) {
    final rect = getBoundingIntegerRect(bounds);
    // print(rect);
    for (var x = rect.left; x <= rect.right; ++x) {
      for (var y = rect.top; y <= rect.bottom; ++y) {
        _barriers.set(GridPosition(x, y), true);
      }
    }
  }
}

class GridPosition {
  final int x;
  final int y;

  const GridPosition(this.x, this.y);

  static const zero = GridPosition(0, 0);

  Offset toOffset() => Offset(x.toDouble(), y.toDouble());

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
      return;
      // throw ArgumentError.value(position);
    }
    final row = _cells[position.y];
    if (position.x < 0 || position.x >= row.length) {
      return;
      // throw ArgumentError.value(position);
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

class BarrierDebug extends RectangleComponent with HasGameRef<GameState> {
  @override
  void render(Canvas canvas) {
    var barriers = gameRef.grid._barriers;
    var passable = Paint()..color = const Color.fromARGB(128, 0, 255, 0);
    var obstacle = Paint()..color = const Color.fromARGB(128, 255, 0, 0);

    for (var position in barriers.allPositions) {
      var paint = barriers.get(position)! ? obstacle : passable;
      canvas.drawRect(position.toOffset() & const Size(1.0, 1.0), paint);
    }
  }
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
    add(BarrierDebug());
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
    addAll(barriers);
  }

  void startWave() {
    addAll([
      for (var position in _generateAttackerPositions(1))
        Attacker()
          ..position = position
          ..anchor = Anchor.center,
    ]);
  }
}
