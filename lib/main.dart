import 'package:material_ui/material_ui.dart';

import 'pages/login_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const McMapApp());
}

class McMapApp extends StatelessWidget {
  const McMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'McMap',
      debugShowCheckedModeBanner: false,
      theme: buildMcMapTheme(),
      home: const LoginPage(),
    );
  }
}
