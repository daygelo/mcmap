import 'package:material_ui/material_ui.dart';

import '../../models/student_visibility.dart';

export '../../models/student_visibility.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.rsvpVisibility,
    required this.profileVisibility,
  });

  final ValueNotifier<StudentVisibility> rsvpVisibility;
  final ValueNotifier<StudentVisibility> profileVisibility;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Privacy',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Demo only. Choices reset when the app restarts. '
                  'Backend privacy enforcement is pending.',
                ),
                const SizedBox(height: 20),
                _VisibilitySection(
                  title: 'Who can see my RSVPs?',
                  value: rsvpVisibility,
                  descriptions: const [
                    'Only me.',
                    'Only my accepted friends.',
                    'Other McMap students may see my attendance.',
                  ],
                ),
                const SizedBox(height: 8),
                const Text('This default applies only to new RSVPs.'),
                const SizedBox(height: 20),
                _VisibilitySection(
                  title: 'Who can view my profile?',
                  value: profileVisibility,
                  descriptions: const [
                    'Only me.',
                    'Only my accepted friends can view my profile.',
                    'Other McMap students can view my profile.',
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilitySection extends StatelessWidget {
  const _VisibilitySection({
    required this.title,
    required this.value,
    required this.descriptions,
  });

  final String title;
  final ValueNotifier<StudentVisibility> value;
  final List<String> descriptions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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
                          subtitle: Text(descriptions[option.index]),
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
