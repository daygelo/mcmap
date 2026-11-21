import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('login page shows Microsoft sign-in action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Welcome to McMap'), findsOneWidget);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
  });
}
