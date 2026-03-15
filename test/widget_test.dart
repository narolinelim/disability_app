import 'package:flutter_test/flutter_test.dart';

import 'package:disability_app/main.dart';

void main() {
  testWidgets('renders SenseBridge home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SenseBridgeApp());

    expect(find.text('SenseBridge'), findsOneWidget);
    expect(find.text('Obstacles'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Sign'), findsOneWidget);
    expect(find.text('Noise'), findsOneWidget);
  });
}
