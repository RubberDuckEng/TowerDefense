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
    width = 20;
    height = 20;
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), _paint);
  }
}

class Attacker extends RectangleComponent {
  static final _paint = Paint()..color = Colors.red.shade400;

  Attacker() {
    width = 10;
    height = 10;
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), _paint);
  }
}

class GameState extends FlameGame {
  @override
  Future<void> onLoad() async {
    addAll([
      Objective()
        ..position = Vector2(size.x / 2, size.y - 10)
        ..anchor = Anchor.bottomCenter,
    ]);
    startWave();
  }

  Iterable<Vector2> _generateAttackerPositions(int count) sync* {
    for (int i = 0; i < count; i++) {
      yield Vector2(math.Random().nextDouble() * size.x, 10);
    }
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
