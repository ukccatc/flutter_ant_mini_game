import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/particles.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const int endGameCount = 30;
const Color _brandGreen = Color(0xFF2E7D4F);
const Color _brandCream = Color(0xFFF7F1E3);
const Color _brandInk = Color(0xFF1C241E);
const Color _brandMuted = Color(0xFF5C6B61);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Browsers cannot lock orientation or true fullscreen the same way as phones.
  if (!kIsWeb) {
    await Flame.device.fullScreen();
    await Flame.device.setLandscape();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: GameWidget(
          game: AntSquashGame(),
          backgroundBuilder: (context) => Container(color: Colors.white),
          overlayBuilderMap: {
            'Instructions': (context, AntSquashGame game) =>
                InstructionsOverlay(game: game),
            'GameOver': (context, AntSquashGame game) =>
                GameOverOverlay(game: game),
            'Congrats': (context, AntSquashGame game) =>
                CongratsOverlay(game: game),
          },
        ),
      ),
    );
  }
}

class AntSquashGame extends FlameGame with TapDetector {
  final double antSize = 35.0;
  final Random random = Random();
  late Vector2 center;
  bool isGameOver = false;
  int score = 0;

  TextComponent scoreText = TextComponent();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Set initial center based on game size
    center = size / 2;

    add(PicnicTarget());

    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(30, 15),
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

    // Pause the game and show instructions overlay before starting.
    pauseEngine();
    overlays.add('Instructions');
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    // Keep our center updated if the screen size changes
    center = newSize / 2;
  }

  /// Called when the player taps "Start Game" on the instructions overlay.
  void startGame() {
    isGameOver = false;
    score = 0;
    scoreText.text = 'Score: 0';
    overlays.remove('Instructions');
    overlays.remove('GameOver');
    overlays.remove('Congrats');
    removeAll(children.whereType<Ant>());
    resumeEngine();
    spawnAntsContinuously();
  }

  void showMenu() {
    isGameOver = true;
    pauseEngine();
    removeAll(children.whereType<Ant>());
    overlays.remove('GameOver');
    overlays.remove('Congrats');
    overlays.add('Instructions');
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
    removeAll(children.whereType<Ant>());
    overlays.add('GameOver');
  }

  void winGame() {
    isGameOver = true;
    pauseEngine();
    removeAll(children.whereType<Ant>());
    overlays.add('Congrats');
  }

  void restartGame() {
    isGameOver = false;
    score = 0;
    scoreText.text = 'Score: 0';
    overlays.remove('GameOver');
    overlays.remove('Congrats');
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
        // Add a smash effect at the ant's position.
        add(SmashEffect(position: ant.position.clone()));
        ant.removeFromParent();
        score++;
        scoreText.text = 'Score: $score';

        if (score >= endGameCount) {
          winGame();
          break;
        }
        break;
      }
    }
  }
}

class Ant extends SpriteComponent with HasGameRef<AntSquashGame> {
  final double antSize;
  final Random random;
  @override
  final Vector2 center;
  final double speed;
  final String enemyType;
  final double _wobbleAmp;
  final double _wobbleFreq;
  final double _speedJitter;
  double _wobblePhase;

  Ant._internal({
    required this.antSize,
    required this.random,
    required this.center,
    required this.enemyType,
    required this.speed,
    required double wobbleAmp,
    required double wobbleFreq,
    required double speedJitter,
    required double wobblePhase,
  })  : _wobbleAmp = wobbleAmp,
        _wobbleFreq = wobbleFreq,
        _speedJitter = speedJitter,
        _wobblePhase = wobblePhase {
    size = Vector2.all(antSize);
  }

  factory Ant({
    required double antSize,
    required Random random,
    required Vector2 center,
  }) {
    final bool isAnt = random.nextBool();
    return Ant._internal(
      antSize: antSize,
      random: random,
      center: center,
      enemyType: isAnt ? 'ant' : 'bug',
      speed: isAnt ? 88.0 : 64.0,
      wobbleAmp: isAnt ? 26.0 : 52.0,
      wobbleFreq: isAnt ? 2.6 : 4.4,
      speedJitter: 0.82 + random.nextDouble() * 0.4,
      wobblePhase: random.nextDouble() * pi * 2,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('$enemyType.png');
    anchor = Anchor.center;
    position = getRandomEdgePosition();
    _facePicnic(center - position);
  }

  Vector2 getRandomEdgePosition() {
    final screenSize = gameRef.size;
    final margin = 8.0;
    switch (random.nextInt(4)) {
      case 0:
        return Vector2(margin + random.nextDouble() * (screenSize.x - margin * 2), 0);
      case 1:
        return Vector2(
          margin + random.nextDouble() * (screenSize.x - margin * 2),
          screenSize.y,
        );
      case 2:
        return Vector2(0, margin + random.nextDouble() * (screenSize.y - margin * 2));
      default:
        return Vector2(
          screenSize.x,
          margin + random.nextDouble() * (screenSize.y - margin * 2),
        );
    }
  }

  /// Ant sprite faces top-right; bug sprite faces up. Keep the head aimed
  /// at the picnic, with a small weave tilt.
  void _facePicnic(Vector2 toTarget) {
    if (toTarget.length2 < 0.0001) return;
    final spriteOffset = enemyType == 'bug' ? pi / 2 : pi / 4;
    final deviation = sin(_wobblePhase) * 0.28;
    angle = atan2(toTarget.y, toTarget.x) + spriteOffset + deviation;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isGameOver) return;

    final targets = gameRef.children.whereType<PicnicTarget>();
    if (targets.isEmpty) return;
    final target = targets.first;

    final toTarget = target.position - position;
    final reach = target.size.x * 0.42;
    if (toTarget.length < reach) {
      gameRef.endGame();
      removeFromParent();
      return;
    }

    final forward = toTarget.normalized();
    final side = Vector2(-forward.y, forward.x);
    _wobblePhase += dt * _wobbleFreq;
    final weave = sin(_wobblePhase) * _wobbleAmp;
    final velocity = (forward * speed + side * weave) * _speedJitter;
    position += velocity * dt;
    _facePicnic(toTarget);
  }
}

class PicnicTarget extends SpriteComponent with HasGameRef<AntSquashGame> {
  PicnicTarget();

  double _pulse = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('watermelon.png');
    size = Vector2.all(72);
    anchor = Anchor.center;
    position = gameRef.size / 2;
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    position = newSize / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 2.2;
    final scale = 1.0 + sin(_pulse) * 0.04;
    size = Vector2.all(72 * scale);
  }
}

class SmashEffect extends ParticleSystemComponent {
  SmashEffect({required Vector2 position})
      : super(
    particle: Particle.generate(
      count: 30,
      lifespan: 0.11,
      generator: (i) {
        final angle = (2 * pi * i) / 20;
        return AcceleratedParticle(
          acceleration: Vector2(cos(angle), sin(angle)) * 150,
          speed: Vector2(cos(angle), sin(angle)) * 150,
          child: WiderParticle(
            width: 7.0,
            height: 7.0,
            paint: Paint()..color = Colors.red,
          ),
        );
      },
    ),
  ) {
    this.position = position;
    anchor = Anchor.center;
  }
}

class WiderParticle extends Particle {
  final double width;
  final double height;
  final Paint paint;

  WiderParticle({
    required this.width,
    required this.height,
    required this.paint,
  });

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      paint,
    );
  }

  @override
  bool update(double dt) => false;
}

class GameOverOverlay extends StatelessWidget {
  final AntSquashGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return _GameScrim(
      child: _GameCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Game Over",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _brandInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "An ant reached the picnic.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: _brandMuted, height: 1.35),
            ),
            const SizedBox(height: 16),
            Text(
              "${game.score}",
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: _brandGreen,
              ),
            ),
            const Text(
              "score",
              style: TextStyle(fontSize: 14, color: _brandMuted),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(label: "Play again", onPressed: game.restartGame),
            const SizedBox(height: 8),
            _TextAction(label: "Back to menu", onPressed: game.showMenu),
          ],
        ),
      ),
    );
  }
}

class CongratsOverlay extends StatelessWidget {
  final AntSquashGame game;

  const CongratsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return _GameScrim(
      child: _GameCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 52, color: Color(0xFFE0A800)),
            const SizedBox(height: 12),
            const Text(
              "Picnic saved!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _brandInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You reached $endGameCount points.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: _brandMuted, height: 1.35),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(label: "Play again", onPressed: game.restartGame),
            const SizedBox(height: 8),
            _TextAction(label: "Back to menu", onPressed: game.showMenu),
          ],
        ),
      ),
    );
  }
}

class InstructionsOverlay extends StatelessWidget {
  final AntSquashGame game;

  const InstructionsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return _GameScrim(
      child: _GameCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 96,
              height: 96,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 16),
            const Text(
              "Ant Squash",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _brandInk,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Protect the picnic",
              style: TextStyle(fontSize: 15, color: _brandMuted),
            ),
            const SizedBox(height: 20),
            const _HowToRow(
              icon: Icons.touch_app,
              text: "Tap ants and bugs to smash them.",
            ),
            const _HowToRow(
              icon: Icons.star,
              text: "Each smash is 1 point.",
            ),
            const _HowToRow(
              icon: Icons.shield,
              text: "Don't let them reach the watermelon.",
            ),
            const _HowToRow(
              icon: Icons.flag,
              text: "Score 30 points to win.",
            ),
            const SizedBox(height: 24),
            _PrimaryButton(label: "Start game", onPressed: game.startGame),
          ],
        ),
      ),
    );
  }
}

class _GameScrim extends StatelessWidget {
  final Widget child;

  const _GameScrim({required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(child: child),
    );
  }
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Material(
        color: _brandCream,
        elevation: 8,
        shadowColor: const Color(0x66000000),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: child,
        ),
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HowToRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: _brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _brandGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TextAction({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: _brandGreen),
      child: Text(label),
    );
  }
}