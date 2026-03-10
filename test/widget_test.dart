import 'package:flutter_test/flutter_test.dart';
import 'package:clipkid/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ClipKidApp());
    expect(find.text('ClipKid'), findsOneWidget);
  });
}
