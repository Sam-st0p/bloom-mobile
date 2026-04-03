import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_gad_app/main.dart';

void main() {
  testWidgets('BLOOM GAD app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BloomApp());
    expect(find.byType(BloomApp), findsOneWidget);
  });
}