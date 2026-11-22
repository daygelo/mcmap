import 'package:material_ui/material_ui.dart';

import '../../models/student_visibility.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.rsvpVisibility,
    this.handle,
    this.onSignOut,
  });

  final ValueNotifier<StudentVisibility> rsvpVisibility;

  /// Of the signed-in account, without the "@".
  final String? handle;

  /// Null in the offline demo, which has no account.
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Privacy', style: text.headlineSmall),
                if (onSignOut == null) ...[
                  const SizedBox(height: 8),
                  const Text('Demo: your choice resets when the app restarts.'),
                ],
                const SizedBox(height: 16),
                _RsvpVisibilitySection(value: rsvpVisibility),
                const SizedBox(height: 8),
                const Text(
                  'Applies to new RSVPs. The ones you already have keep the '
                  'audience they were made with.',
                ),
                if (onSignOut case final signOut?) ...[
                  const SizedBox(height: 32),
                  Text('Account', style: text.headlineSmall),
                  const SizedBox(height: 16),
                  _SignOutTile(handle: handle, onSignOut: signOut),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignOutTile extends StatefulWidget {
  const _SignOutTile({required this.handle, required this.onSignOut});

  final String? handle;
  final Future<void> Function() onSignOut;

  @override
  State<_SignOutTile> createState() => _SignOutTileState();
}

class _SignOutTileState extends State<_SignOutTile> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
      // The login page is now underneath.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't sign out. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: const Icon(Icons.logout_rounded, color: McMapColors.burgundy),
      title: Text(_signingOut ? 'Signing out…' : 'Sign out'),
      titleTextStyle: Theme.of(context).textTheme.titleMedium,
      subtitle: switch (widget.handle) {
        final handle? => Text('Signed in as @$handle'),
        null => null,
      },
      enabled: !_signingOut,
      onTap: _signOut,
    ),
  );
}

class _RsvpVisibilitySection extends StatelessWidget {
  const _RsvpVisibilitySection({required this.value});

  final ValueNotifier<StudentVisibility> value;

  static const _descriptions = {
    StudentVisibility.private: 'Only me.',
    StudentVisibility.friends: 'Only McGillians who follow me.',
    StudentVisibility.public: 'Other McMap students may see my attendance.',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Who can see my RSVPs?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ValueListenableBuilder(
              valueListenable: value,
              builder: (context, selected, child) {
                return RadioGroup<StudentVisibility>(
                  groupValue: selected,
                  onChanged: (selection) {
                    if (selection != null) value.value = selection;
                  },
                  child: Column(
                    children: [
                      for (final option in StudentVisibility.values)
                        RadioListTile<StudentVisibility>(
                          value: option,
                          title: Text(option.label),
                          subtitle: Text(_descriptions[option]!),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
