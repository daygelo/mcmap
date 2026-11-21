import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mcmap/main.dart';
import 'package:mcmap/pages/login_page.dart';

void main() {
  testWidgets('shows configuration guidance without credentials', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McMapApp());

    expect(find.text('Supabase configuration required'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });

  testWidgets('login starts with only the McGill email field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Welcome to McMap'), findsOneWidget);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('email-confirmation-checkbox')), findsNothing);
  });

  test('accepts McGill email domains', () {
    expect(isMcGillEmail('student@mcgill.ca'), isTrue);
    expect(isMcGillEmail('student@mail.mcgill.ca'), isTrue);
    expect(isMcGillEmail('student@example.com'), isFalse);
  });

  test('creates a default name from a McGill email', () {
    expect(defaultNameFromEmail('angela.morin@mail.mcgill.ca'), 'Angela Morin');
  });
}
