import 'package:material_ui/material_ui.dart';

import '../../data/academics.dart';
import '../../models/user_profile.dart';
import 'interests_page.dart';

/// Onboarding step 1: pick a faculty, then a major within it.
class AcademicInfoPage extends StatefulWidget {
  const AcademicInfoPage({super.key});

  @override
  State<AcademicInfoPage> createState() => _AcademicInfoPageState();
}

class _AcademicInfoPageState extends State<AcademicInfoPage> {
  String? _faculty;
  String? _major;

  bool get _canContinue => _faculty != null && _major != null;

  void _selectFaculty(String faculty) {
    if (faculty == _faculty) return;
    setState(() {
      _faculty = faculty;
      _major = null;
    });
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InterestsPage(
          profile: UserProfile(faculty: _faculty!, major: _major!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final majors = _faculty == null
        ? const <String>[]
        : majorsByFaculty[_faculty]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 2')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'What do you study?',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'We use this to show you relevant buildings, events and people.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                Text('Faculty', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final faculty in majorsByFaculty.keys)
                      ChoiceChip(
                        label: Text(faculty),
                        selected: faculty == _faculty,
                        onSelected: (_) => _selectFaculty(faculty),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Major', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // Rebuild when the faculty changes so the old major clears.
                  key: ValueKey(_faculty),
                  initialValue: _major,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _faculty == null
                        ? 'Pick a faculty first'
                        : 'Select your major',
                  ),
                  items: [
                    for (final major in majors)
                      DropdownMenuItem(value: major, child: Text(major)),
                  ],
                  onChanged: _faculty == null
                      ? null
                      : (value) => setState(() => _major = value),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            onPressed: _canContinue ? _continue : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}
