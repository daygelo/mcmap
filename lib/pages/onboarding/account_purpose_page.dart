import 'package:material_ui/material_ui.dart';

import '../../widgets/auth_scaffold.dart';

class AccountPurposePage extends StatelessWidget {
  const AccountPurposePage({
    super.key,
    required this.onStudent,
    required this.onOrganizer,
    required this.onSignOut,
  });

  final VoidCallback onStudent;
  final VoidCallback onOrganizer;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => AuthScaffold(
    icon: Icons.person_outline,
    title: 'How will you use McMap?',
    subtitle: 'Choose how to get started. Students can apply for publishing access from Profile.',
    children: [
      FilledButton(onPressed: onStudent, child: const Text('Student')),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: onOrganizer,
        child: const Text('Faculty / Club Executive'),
      ),
      TextButton(onPressed: onSignOut, child: const Text('Sign out')),
    ],
  );
}
