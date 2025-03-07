import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart'; // Ensure this package is added in pubspec.yaml

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
        backgroundColor: Colors.white, // Set background to white
        body: GameWidget(
          game: AntSquashGame(),
          backgroundBuilder: (context) => Container(color: Colors.white),
          overlayBuilderMap: {

            'GameOver': (context, AntSquashGame game) =>
                GameOverOverlay(game: game),
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
  int score = 0;

  TextComponent scoreText = TextComponent();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    center = size / 2;
    add(Corn(initialCenter: center));

    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(10, 10),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);

    await FlameAudio.audioCache.load('squish.mp3');

    spawnAntsContinuously();
  }

  void spawnAntsContinuously() async {
    while (!isGameOver) {
      await Future.delayed(
          Duration(milliseconds: random.nextInt(1000) + 500));
      if (!isGameOver) {
        add(Ant(antSize: antSize, random: random, center: center));
      }
    }
  }

  void endGame() {
    isGameOver = true;
    pauseEngine();
    overlays.add('GameOver');
  }

  void restartGame() {
    isGameOver = false;
    score = 0;
    scoreText.text = 'Score: 0';
    overlays.remove('GameOver');
    resumeEngine();
    removeAll(children.whereType<Ant>());
    spawnAntsContinuously();
  }

  @override
  void onTapDown(TapDownInfo info) {
    final tapPosition = info.eventPosition.global;

    for (final ant in children.whereType<Ant>().toList()) {
      final Rect enlargedHitBox = ant.toRect().inflate(20.0);
      if (enlargedHitBox.contains(tapPosition.toOffset())) {
        FlameAudio.play('squish.mp3');
        ant.removeFromParent();
        score++;
        scoreText.text = 'Score: $score';
        break;
      }
    }
  }
}

class Ant extends SpriteComponent with HasGameRef<AntSquashGame> {
  final double antSize;
  final Random random;
  final Vector2 center;
  final double speed = 100.0;

  Ant({required this.antSize, required this.random, required this.center}) {
    size = Vector2.all(antSize);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('ant.png');
    anchor = Anchor.center;
    position = getRandomEdgePosition();
    angle = atan2(center.y - position.y, center.x - position.x) + pi / 4;
  }

  Vector2 getRandomEdgePosition() {
    final screenSize = gameRef.size;
    switch (random.nextInt(4)) {
      case 0:
        return Vector2(random.nextDouble() * screenSize.x, 0);
      case 1:
        return Vector2(random.nextDouble() * screenSize.x, screenSize.y);
      case 2:
        return Vector2(0, random.nextDouble() * screenSize.y);
      case 3:
        return Vector2(screenSize.x, random.nextDouble() * screenSize.y);
      default:
        return Vector2.zero();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isGameOver) return;

    // Get the corn component to use its center position
    final corn = gameRef.children.whereType<Corn>().first;

    // Calculate the direction vector from the ant's position towards the corn's center
    final direction = (corn.position - position).normalized();
    position += direction * speed * dt;

    // End game when the ant's center is near the corn's center
    if (position.distanceTo(corn.position) < 3) {
      gameRef.endGame();
      removeFromParent();
    }
  }
}

class Corn extends SpriteComponent {
  final Vector2 initialCenter;

  Corn({required this.initialCenter});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('corn.png');
    size = Vector2.all(60);
    anchor = Anchor.center;
    position = initialCenter;
  }


}

class GameOverOverlay extends StatelessWidget {
  final AntSquashGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AlertDialog(
        title: const Text("Game Over"),
        content: Text("An ant reached the corn!\nYour score: ${game.score}"),
        actions: [
          TextButton(
            onPressed: game.restartGame,
            child: const Text("Quit"),
          ),
          const SizedBox(width: 20), // adjust width as needed
          TextButton(
            onPressed: game.restartGame,
            child: const Text("Restart"),
          ),
        ],
      ),
    );
  }
}