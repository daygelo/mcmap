import 'package:material_ui/material_ui.dart';

import '../../models/student_visibility.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.rsvpVisibility});

  final ValueNotifier<StudentVisibility> rsvpVisibility;

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
                const Text('Your default resets when the app restarts.'),
                const SizedBox(height: 20),
                _RsvpVisibilitySection(value: rsvpVisibility),
                const SizedBox(height: 8),
                const Text('This default applies only to new RSVPs.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RsvpVisibilitySection extends StatelessWidget {
  const _RsvpVisibilitySection({required this.value});

  final ValueNotifier<StudentVisibility> value;

  static const _descriptions = {
    StudentVisibility.private: 'Only me.',
    StudentVisibility.friends: 'Only my accepted friends.',
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
