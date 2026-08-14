import 'package:flutter_test/flutter_test.dart';
import 'package:mini_game/main.dart';

void main() {
  testWidgets('shows start instructions', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('Start Game'), findsOneWidget);
  });
}
