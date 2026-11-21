import 'package:material_ui/material_ui.dart';

import 'student_profile.dart';

const _faculties = [
  'Faculty of Engineering',
  'Faculty of Arts',
  'Faculty of Science',
  'Desautels Faculty of Management',
  'Faculty of Education',
  'Other',
];
const _years = ['U0', 'U1', 'U2', 'U3', 'U4'];
const _interestOptions = [
  'Programming',
  'Gaming',
  'Robotics',
  'Sports',
  'Music',
  'Photography',
  'Art',
  'Literature',
  'Volunteering',
  'Entrepreneurship',
  'Social events',
  'Academic workshops',
];

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.profile,
    required this.onSave,
  });

  final StudentProfile profile;
  final Future<void> Function(StudentProfile) onSave;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _major = TextEditingController(text: widget.profile.major);
  late final _bio = TextEditingController(text: widget.profile.bio);
  late final _interests = {...widget.profile.interests};
  late String _faculty = widget.profile.faculty;
  late String _year = widget.profile.year;
  bool _saving = false;

  @override
  void dispose() {
    _major.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.onSave(
        StudentProfile(
          faculty: _faculty,
          major: _major.text.trim(),
          year: _year,
          bio: _bio.text.trim(),
          interests: Set.unmodifiable(_interests),
          avatarUrl: widget.profile.avatarUrl,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save changes. Try again.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ProfileAvatar(profile: widget.profile),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: null,
                        child: Text('Change picture'),
                      ),
                    ),
                    const Text('Picture changes require avatar storage.'),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _faculty,
                      decoration: const InputDecoration(labelText: 'Faculty'),
                      items: [
                        for (final option in _faculties)
                          DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _faculty = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _major,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Major/program',
                      ),
                      maxLength: 100,
                      validator: (value) => value!.trim().isEmpty
                          ? 'Enter your major or program.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Academic year',
                      ),
                      items: [
                        for (final option in _years)
                          DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _year = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bio,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'About me',
                        hintText: 'Tell other McGill students a little about yourself...',
                      ),
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 250,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Interests',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final interest in _interestOptions)
                          FilterChip(
                            label: Text(interest),
                            selected: _interests.contains(interest),
                            onSelected: _saving
                                ? null
                                : (selected) => setState(() {
                                    if (selected) {
                                      _interests.add(interest);
                                    } else {
                                      _interests.remove(interest);
                                    }
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Demo changes last until the app restarts.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save Changes'),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
