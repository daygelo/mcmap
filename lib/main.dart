import 'package:material_ui/material_ui.dart';

import 'pages/home_page.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5A75)),
      ),
      home: const HomePage(),
    );
  }
}