import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motify/app.dart';

void main() {
  testWidgets('App boots to the onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MotifyApp()));
    await tester.pump();

    expect(find.text('Get started'), findsOneWidget);
  });
}
