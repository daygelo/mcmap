import 'package:material_ui/material_ui.dart';

import '../../models/student_visibility.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.rsvpVisibility,
    required this.onSave,
    required this.demo,
    this.onSignOut,
    this.accountName,
  });

  final ValueNotifier<StudentVisibility> rsvpVisibility;
  final Future<void> Function(StudentVisibility) onSave;
  final bool demo;
  final String? accountName;
  final Future<void> Function()? onSignOut;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  static const _descriptions = {
    StudentVisibility.private: 'Only you can see your attendance.',
    StudentVisibility.friends: 'Only McGillians you follow who also follow you can see your attendance.',
    StudentVisibility.public: 'Signed-in McMap users can see your attendance.',
  };

  Future<void> _select(StudentVisibility? selection) async {
    if (_busy ||
        selection == null ||
        selection == widget.rsvpVisibility.value) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (selection == StudentVisibility.public) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Make all RSVPs public?'),
            content: const Text(
              'Signed-in McMap users will be able to see your attendance at '
              'events you already RSVPed to and events you RSVP to in the future.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Make public'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      await widget.onSave(selection);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't confirm your RSVP privacy. Check your connection and try again.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                const SizedBox(height: 8),
                Text(
                  widget.demo
                      ? 'Changes apply to all existing and future RSVPs in this demo session.'
                      : 'Changes apply to all existing and future RSVPs on your account.',
                ),
                const SizedBox(height: 20),
                Card(
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
                          valueListenable: widget.rsvpVisibility,
                          builder: (context, selected, _) =>
                              RadioGroup<StudentVisibility>(
                                groupValue: selected,
                                onChanged: _select,
                                child: Column(
                                  children: [
                                    for (final option
                                        in StudentVisibility.values)
                                      RadioListTile<StudentVisibility>(
                                        enabled: !_busy,
                                        value: option,
                                        title: Text(option.label),
                                        subtitle: Text(_descriptions[option]!),
                                      ),
                                  ],
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onSignOut case final signOut?) ...[
                  const SizedBox(height: 32),
                  Text('Account', style: text.headlineSmall),
                  const SizedBox(height: 16),
                  _SignOutTile(
                    accountName: widget.accountName,
                    onSignOut: signOut,
                  ),
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
  const _SignOutTile({required this.accountName, required this.onSignOut});

  final String? accountName;
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
      subtitle: switch (widget.accountName) {
        final name? => Text('Signed in as $name'),
        null => null,
      },
      enabled: !_signingOut,
      onTap: _signOut,
    ),
  );
}
