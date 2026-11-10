import 'package:flutter_test/flutter_test.dart';
import 'package:stella_tracker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StellaCompanion());
    expect(find.byType(StellaCompanion), findsOneWidget);
  });
}
