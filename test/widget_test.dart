import 'package:flutter_test/flutter_test.dart';
import 'package:clipkid/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ClipKidApp());
    // Allow the post-frame callback that offers the duck guide to run.
    await tester.pump();
    expect(find.byType(ClipKidApp), findsOneWidget);
  });
}
