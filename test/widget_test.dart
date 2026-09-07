import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mytune/app/app.dart';

void main() {
  testWidgets('MyTuneApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyTuneApp(),
      ),
    );

    // Initial frame rendered successfully
    expect(find.byType(MyTuneApp), findsOneWidget);
  });
}
