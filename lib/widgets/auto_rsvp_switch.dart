import 'package:material_ui/material_ui.dart';

class AutoRsvpSwitch extends StatelessWidget {
  const AutoRsvpSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Auto-RSVP to events'),
    subtitle: const Text(
      'Automatically RSVP to eligible new events from this organization. You can cancel anytime.',
    ),
    value: value,
    onChanged: onChanged,
  );
}
