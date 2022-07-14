import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/body_component.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:forge2d/forge2d.dart';

import 'nav_grid.dart';

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

class Barrier extends BodyComponent<GameState> {
  static final _paint = Paint()..color = Colors.blue.shade400;

  Vector2 position = Vector2.zero();
  Vector2 size = Vector2.all(2);

  Barrier() : super(paint: _paint);

  @override
  void onMount() {
    super.onMount();
    gameRef.grid.markNotPassable(Rect.fromCenter(
        center: Offset(position.x, position.y), width: size.x, height: size.y));
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: position,
    );
    final body = world.createBody(bodyDef);
    final shape = PolygonShape()..setAsBoxXY(size.x / 2, size.y / 2);
    body.createFixtureFromShape(shape);
    return body;
  }
}

class Attacker extends BodyComponent<GameState> {
  static final _paint = Paint()..color = Colors.red.shade400;

  final double _speed = 2.0;

  double closeEnough = 0.1;
  List<Offset> waypoints = [];

  Vector2 initialPosition = Vector2.zero();

  Attacker() : super(paint: _paint);

  Vector2 get objective => gameRef.objective.center;

  @override
  void onMount() {
    moveTo(objective.toOffset());
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
    super.update(dt);
    // var nextWaypoint = getNextWaypoint();
    // if (nextWaypoint == null) {
    //   return;
    // }
    // final center = this.center;
    // if (center.distanceTo(nextWaypoint) < closeEnough) {
    //   waypoints.removeAt(0);
    //   nextWaypoint = getNextWaypoint();
    //   if (nextWaypoint == null) {
    //     return;
    //   }
    // }
    final force = objective - center
      ..normalize()
      ..scale(_speed);
    body.applyForce(force);
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
    );
    final body = world.createBody(bodyDef);
    final shape = CircleShape()..radius = 0.5;
    body.createFixtureFromShape(shape, 1.0);
    return body;
  }
}

class BarrierDebug extends RectangleComponent with HasGameRef<GameState> {
  @override
  void render(Canvas canvas) {
    var barriers = gameRef.grid.barriers;
    var passable = Paint()..color = const Color.fromARGB(128, 0, 255, 0);
    var obstacle = Paint()..color = const Color.fromARGB(128, 255, 0, 0);

    for (int y = 0; y < barriers.height; ++y) {
      for (int x = 0; x < barriers.width; ++x) {
        var paint = barriers.get(x, y)! ? obstacle : passable;
        canvas.drawRect(
            Offset(x.toDouble(), y.toDouble()) & const Size(0.9, 0.9), paint);
      }
    }
  }
}

class GameState extends Forge2DGame {
  late Objective objective;
  final NavGrid grid = NavGrid();

  GameState() : super(gravity: Vector2.zero());

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(Vector2.all(1000.0));
    addBarriers();
    objective = Objective()
      ..position = Vector2(size.x / 2, size.y - 1)
      ..anchor = Anchor.bottomCenter;
    add(objective);
    // add(BarrierDebug());
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
        Barrier()..position = position
    ];
    addAll(barriers);
  }

  void startWave() {
    addAll([
      for (var position in _generateAttackerPositions(50))
        Attacker()..initialPosition = position,
    ]);
  }
}
