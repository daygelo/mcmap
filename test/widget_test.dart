import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcmap/main.dart';

/// Login → pick Engineering / Software Engineering → land on interests.
Future<void> _goToInterests(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const McMapApp());
  expect(find.text('Welcome to McMap'), findsOneWidget);

  await tester.tap(find.text('Continue with Microsoft'));
  await tester.pumpAndSettle();
  expect(find.text('What do you study?'), findsOneWidget);

  await tester.tap(find.text('Engineering'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Software Engineering').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('What are you into?'), findsOneWidget);
}

void main() {
  testWidgets('picking interests carries them to home', (tester) async {
    await _goToInterests(tester);

    for (final name in ['Music', 'Coding', 'Coffee']) {
      await tester.tap(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Skip for now'), findsNothing);
    await tester.tap(find.text('Continue · 3 selected'));
    await tester.pumpAndSettle();

    expect(find.text('Software Engineering · Engineering'), findsOneWidget);
    expect(find.text('Coding'), findsOneWidget);
  });

  testWidgets('interests step can be skipped with none selected', (
    tester,
  ) async {
    await _goToInterests(tester);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Software Engineering · Engineering'), findsOneWidget);
    expect(find.textContaining('popular events from Engineering'), findsOne);
  });
}
