import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(
          game: AntSquashGame(),
          overlayBuilderMap: {
            'GameOver': (context, AntSquashGame game) => GameOverOverlay(game: game),
          },
        ),
      ),
    );
  }
}

class AntSquashGame extends FlameGame with TapDetector {
  final double antSize = 50.0;
  final Random random = Random();
  late Vector2 center;
  bool isGameOver = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    center = size / 2;
    add(Corn(center: center));
    spawnAntsContinuously();
  }

  @override
  void render(Canvas canvas) {
    // Draw a white rectangle covering the entire canvas.
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(rect, paint);

    // Render the rest of the game.
    super.render(canvas);
  }

  void spawnAntsContinuously() async {
    while (!isGameOver) {
      await Future.delayed(Duration(milliseconds: random.nextInt(1000) + 500));
      if (!isGameOver) {
        add(Ant(antSize: antSize, random: random, center: center));
      }
    }
  }

  void endGame() {
    isGameOver = true;
    pauseEngine();
    overlays.add('GameOver'); // Show Game Over UI
  }

  void restartGame() {
    isGameOver = false;
    overlays.remove('GameOver'); // Hide Game Over UI
    resumeEngine();
    removeAll(children.whereType<Ant>());
    spawnAntsContinuously();
  }

  @override
  void onTapDown(TapDownInfo info) {
    final tapPosition = info.eventPosition.global;

    // Inflate each ant's bounding rectangle to make it easier to tap
    for (final ant in children.whereType<Ant>().toList()) {
      final Rect enlargedHitBox = ant.toRect().inflate(20.0); // Increase the clickable area by 20 pixels on all sides
      if (enlargedHitBox.contains(tapPosition.toOffset())) {
        ant.removeFromParent();
        break;
      }
    }
  }
}

class Ant extends SpriteComponent with HasGameRef<AntSquashGame> {
  final double antSize;
  final Random random;
  final Vector2 center;
  final double speed = 100.0; // Pixels per second

  Ant({required this.antSize, required this.random, required this.center}) {
    size = Vector2.all(antSize);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('ant.png');
    position = getRandomEdgePosition();
  }

  Vector2 getRandomEdgePosition() {
    final screenSize = gameRef.size;
    int side = random.nextInt(4); // Random side (0 = top, 1 = bottom, 2 = left, 3 = right)

    switch (side) {
      case 0: return Vector2(random.nextDouble() * (screenSize.x - antSize), 0);
      case 1: return Vector2(random.nextDouble() * (screenSize.x - antSize), screenSize.y - antSize);
      case 2: return Vector2(0, random.nextDouble() * (screenSize.y - antSize));
      case 3: return Vector2(screenSize.x - antSize, random.nextDouble() * (screenSize.y - antSize));
      default: return Vector2.zero();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isGameOver) return;

    Vector2 direction = (center - position).normalized();
    position += direction * speed * dt;

    if (position.distanceTo(center) < 10) {
      gameRef.endGame();
      removeFromParent();
    }
  }
}

class Corn extends SpriteComponent with HasGameRef<AntSquashGame>, CollisionCallbacks {
  final Vector2 center;

  Corn({required this.center});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center; // Центрирование спрайта
    sprite = await Sprite.load('corn.png');
    size = Vector2.all(60);
    position = center + Vector2(20, 20);

    // Добавляем hitbox, который больше, чем спрайт
    // Используем RectangleHitbox.relative, чтобы задать относительный размер и позицию
    final hitbox = RectangleHitbox.relative(
      Vector2(1.5, 1.5), // Размер hitbox увеличен на 50%
      parentSize: size,
      position: Vector2(1, 1), // Смещение, чтобы центрировать hitbox относительно спрайта
    );
    add(hitbox);
  }
}

// Game Over UI using Flame Overlays
class GameOverOverlay extends StatelessWidget {
  final AntSquashGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AlertDialog(
        title: const Text("Game Over"),
        content: const Text("An ant reached the corn!"),
        actions: [
          TextButton(
            onPressed: game.restartGame,
            child: const Text("Restart"),
          ),
        ],
      ),
    );
  }
}
