import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_map/main.dart';

void main() {
  testWidgets('landing page is wrapped in MaterialApp and shows key content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Family Map'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('Sign in'),
      ),
      findsOneWidget,
    );
  });
}
