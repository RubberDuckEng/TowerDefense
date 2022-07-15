import 'dart:math' as math;

import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/body_component.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:forge2d/forge2d.dart';

import 'nav_grid.dart';

final playerMovableDef = MovableDef(
  acceleration: 4.0,
  drag: 0.2,
  debugAcceleratingPaint: Paint()..color = Colors.yellow.shade400,
  debugBreakingPaint: Paint()..color = Colors.green.shade400,
);

class Player extends Movable {
  Player() : super(movableDef: playerMovableDef);

  @override
  Vector2 objective = Vector2.zero();

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
    );
    final body = world.createBody(bodyDef);
    final shape = CircleShape()..radius = 2.0;
    body.createFixtureFromShape(shape, 0.1);
    return body;
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

class MovableDef {
  final double acceleration; // m / (s*s)
  final double drag; // 1 / s

  final Paint debugAcceleratingPaint;
  final Paint debugBreakingPaint;

  const MovableDef({
    required this.acceleration,
    required this.drag,
    required this.debugAcceleratingPaint,
    required this.debugBreakingPaint,
  });
}

abstract class Movable extends BodyComponent<GameState> {
  final MovableDef movableDef;

  Vector2 initialPosition = Vector2.zero();

  Movable({required this.movableDef})
      : super(paint: movableDef.debugAcceleratingPaint);

  // FIXME: This should be a chase() call on Movable.  Then movable can have
  // waypoints and reset them when the chase target changes.
  Vector2 get objective;

  @override
  void update(double dt) {
    super.update(dt);

    final vectorToObjective = objective - center;
    final distanceToObjective = vectorToObjective.length;
    final currentSpeed = body.linearVelocity.length;

    final timeToObjective = distanceToObjective / currentSpeed;

    // distance(t) = v * t + (a * t * t) / 2
    // velocity(t) = v + a * t
    // accleration(t) = a

    final timeToBreak = currentSpeed / movableDef.acceleration;

    Vector2 force;
    if (timeToBreak > timeToObjective) {
      paint = movableDef.debugBreakingPaint;
      force = body.linearVelocity.normalized()..scale(-movableDef.acceleration);
    } else {
      paint = movableDef.debugAcceleratingPaint;
      force = vectorToObjective
        ..normalize()
        ..scale(movableDef.acceleration);
      // Apply drag to converge to terminal velocity.
      force += body.linearVelocity * -movableDef.drag;
    }
    body.applyForce(force);
  }
}

final MovableDef attackerMovableDef = MovableDef(
  acceleration: 2.0,
  drag: 0.2,
  debugAcceleratingPaint: Paint()..color = Colors.red.shade400,
  debugBreakingPaint: Paint()..color = Colors.green.shade400,
);

class Attacker extends Movable {
  Attacker() : super(movableDef: attackerMovableDef);

  @override
  Vector2 get objective => gameRef.player.center;

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

class GameState extends Forge2DGame with TapDetector {
  late Player player;
  final NavGrid grid = NavGrid();

  GameState() : super(gravity: Vector2.zero());

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(Vector2.all(1000.0));
    player = Player()..initialPosition = Vector2(size.x / 2, size.y / 2);
    player.objective = player.initialPosition;
    addBarriers();
    add(player);
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

  @override
  void onTapUp(TapUpInfo info) {
    player.objective = info.eventPosition.game;
    super.onTapUp(info);
  }

  void startWave() {
    addAll([
      for (var position in _generateAttackerPositions(50))
        Attacker()..initialPosition = position,
    ]);
  }
}
