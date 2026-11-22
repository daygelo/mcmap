import 'package:material_ui/material_ui.dart';

import '../../data/academics.dart';
import '../../models/user_profile.dart';
import '../../widgets/froshie_tag.dart';
import 'interests_page.dart';

/// Onboarding step 1 (required): the student's academic profile.
///
/// Progressive disclosure, top to bottom:
///   Degree level → U-year (undergrads only) → Faculty → Program / major.
/// Each section appears once the one above it is answered, so nobody sees
/// questions that don't apply to them.
class AcademicInfoPage extends StatefulWidget {
  const AcademicInfoPage({super.key, this.onSignOut});

  /// Shown as "Sign out" in the app bar when onboarding is the first screen
  /// after logging in (there's no back button to leave otherwise).
  final VoidCallback? onSignOut;

  @override
  State<AcademicInfoPage> createState() => _AcademicInfoPageState();
}

class _AcademicInfoPageState extends State<AcademicInfoPage> {
  DegreeLevel? _degree;
  String? _year;

  /// Only asked of U1s: null = unanswered.
  bool? _firstYear;
  String? _faculty;
  AcademicCampus? _campus;

  /// Free text so grad students can type a program that isn't in the list;
  /// picking a suggestion just fills this in.
  final _major = TextEditingController();

  String get _majorText => _major.text.trim();

  bool get _yearDone =>
      _degree != null &&
      (!_degree!.hasUYear ||
          (_year != null && (_year != 'U1' || _firstYear != null)));

  bool get _canContinue =>
      _yearDone &&
      _faculty != null &&
      (!_degree!.requiresMajor || _majorText.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _major.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _major.dispose();
    super.dispose();
  }

  void _selectDegree(DegreeLevel degree) {
    setState(() {
      _degree = degree;
      if (!degree.hasUYear) {
        _year = null;
        _firstYear = null;
      }
    });
  }

  void _selectYear(String year) {
    setState(() {
      _year = year;
      if (year != 'U1') _firstYear = null;
    });
  }

  void _selectFaculty(String faculty) {
    if (faculty == _faculty) return;
    setState(() => _faculty = faculty);
    _major.clear();
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InterestsPage(
          profile: UserProfile(
            degreeLevel: _degree!,
            year: _year,
            firstYearAtMcGill: _firstYear ?? false,
            faculty: _faculty!,
            campus: _campus,
            major: _majorText.isEmpty ? null : _majorText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final degree = _degree;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1 of 3'),
        actions: [
          if (widget.onSignOut case final signOut?)
            TextButton(onPressed: signOut, child: const Text('Sign out')),
        ],
      ),
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
                  'We use this to show you events from your faculty and '
                  'people in your year.',
                  style: theme.textTheme.bodyLarge,
                ),
                _Section(
                  title: 'Degree level',
                  child: _Pills(
                    options: [for (final d in DegreeLevel.values) d.label],
                    selected: degree?.label,
                    onSelected: (label) => _selectDegree(
                      DegreeLevel.values.firstWhere((d) => d.label == label),
                    ),
                  ),
                ),
                _Reveal(
                  visible: degree?.hasUYear ?? false,
                  child: _Section(
                    title: 'Year',
                    helper:
                        'U0 is the freshman / foundation year. Pick U4+ for '
                        'longer degrees like Engineering, co-op or '
                        'Architecture.',
                    child: _Pills(
                      options: academicYears,
                      selected: _year,
                      onSelected: _selectYear,
                    ),
                  ),
                ),
                _Reveal(
                  visible: _year == 'U1',
                  child: _Section(
                    title: 'Is this your first year at McGill?',
                    helper:
                        'For example, entering from CEGEP or with AP/IB '
                        'transfer credits.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Pills(
                          options: const [_firstYearYes, _firstYearNo],
                          selected: switch (_firstYear) {
                            true => _firstYearYes,
                            false => _firstYearNo,
                            null => null,
                          },
                          onSelected: (answer) => setState(
                            () => _firstYear = answer == _firstYearYes,
                          ),
                        ),
                        if (_firstYear == true) const _FroshieNote(),
                      ],
                    ),
                  ),
                ),
                _Reveal(visible: _year == 'U0', child: const _FroshieNote()),
                _Reveal(
                  visible: _yearDone,
                  child: _Section(
                    title: 'Faculty',
                    child: _Pills(
                      options: majorsByFaculty.keys.toList(),
                      selected: _faculty,
                      onSelected: _selectFaculty,
                    ),
                  ),
                ),
                _Reveal(
                  visible: _yearDone && _faculty != null,
                  child: _Section(
                    title: degree?.requiresMajor ?? true
                        ? 'Program / major'
                        : 'Program / major (optional)',
                    helper: _year == 'U0'
                        ? "Haven't declared yet? Pick \"$undeclaredMajor\"."
                        : 'Start typing to search, or enter your program.',
                    child: _MajorField(
                      // New faculty → fresh field with that faculty's list.
                      key: ValueKey(_faculty),
                      controller: _major,
                      options: [undeclaredMajor, ...?majorsByFaculty[_faculty]],
                    ),
                  ),
                ),
                _Reveal(
                  visible: _yearDone && _faculty != null,
                  child: _Section(
                    title: 'Campus (optional)',
                    child: DropdownButtonFormField<AcademicCampus>(
                      initialValue: _campus,
                      isExpanded: true,
                      hint: const Text('Use program campus when known'),
                      items: [
                        for (final campus in AcademicCampus.values)
                          DropdownMenuItem(
                            value: campus,
                            child: Text(campus.label),
                          ),
                      ],
                      onChanged: (campus) => setState(() => _campus = campus),
                    ),
                  ),
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

const _firstYearYes = "Yes, it's my first year";
const _firstYearNo = 'No, returning student';

/// Tells new students they'll get the Froshie badge.
class _FroshieNote extends StatelessWidget {
  const _FroshieNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          const FroshieTag(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Welcome! You'll get the Froshie badge and Frosh event picks.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.helper});

  final String title;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          if (helper case final helper?) ...[
            const SizedBox(height: 4),
            Text(helper, style: text.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Single-select pill group (styled by the theme's ChipThemeData:
/// selected = red tint + McGill red outline + burgundy label).
class _Pills extends StatelessWidget {
  const _Pills({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

/// Smoothly expands a section into view once it becomes relevant.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: visible ? child : const SizedBox(width: double.infinity),
    );
  }
}

/// Searchable major field: filters suggestions as you type, but also accepts
/// a program that isn't listed.
class _MajorField extends StatelessWidget {
  const _MajorField({
    super.key,
    required this.controller,
    required this.options,
  });

  final TextEditingController controller;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      controller: controller,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 320,
      hintText: 'Search programs',
      leadingIcon: const Icon(Icons.search_rounded),
      dropdownMenuEntries: [
        for (final option in options)
          DropdownMenuEntry(value: option, label: option),
      ],
    );
  }
}
