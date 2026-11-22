import 'package:material_ui/material_ui.dart';

import '../../backend/mcmap_backend.dart';
import '../../data/interests.dart';
import '../../data/academic_auto_follows.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interest_pin.dart';
import '../club_picker_page.dart';
import '../home_page.dart';

/// Onboarding step 2 (optional): a grid of interests to tap, each one a pin on
/// its own patch of map.
///
/// Users can leave with zero interests. The bottom button adapts: with nothing
/// selected it's a low-key "Skip for now"; once anything is tapped it becomes
/// the red "Continue" CTA.
class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  final Set<String> _selected = {};
  bool _finishing = false;
  Set<String>? _reviewedFollows;

  void _toggle(String name) {
    setState(() {
      if (!_selected.remove(name)) _selected.add(name);
    });
  }

  Future<void> _continueToClubs() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final ids = await Navigator.of(context).push<Set<String>>(
        MaterialPageRoute(
          builder: (_) => ClubPickerPage(
            academicIds: academicAutoFollowIds(widget.profile),
            initialSelection: _reviewedFollows,
          ),
        ),
      );
      if (!mounted || ids == null) return;
      _reviewedFollows = ids;
      final profile = widget.profile.copyWith(
        interests: _selected,
        followedClubIds: {...widget.profile.followedClubIds, ...ids},
      );

      final backend = BackendScope.maybeOf(context);
      final navigator = Navigator.of(context);
      if (backend == null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomePage(profile: profile)),
          (_) => false,
        );
      } else {
        await backend.completeOnboarding(profile);
        if (mounted) navigator.popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save your profile. Try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _selected.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Step 2 of 3')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OPTIONAL',
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: McMapColors.slate,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'What are you into?',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap a few to tailor your event feed, or skip and '
                      "we'll show you what's popular in your faculty.",
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: allInterests.length,
                itemBuilder: (context, index) {
                  final interest = allInterests[index];
                  return _InterestTile(
                    interest: interest,
                    selected: _selected.contains(interest.name),
                    onTap: () => _toggle(interest.name),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: count == 0
                ? OutlinedButton(
                    key: const ValueKey('skip'),
                    onPressed: _finishing ? null : _continueToClubs,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Skip for now'),
                  )
                : FilledButton(
                    key: const ValueKey('continue'),
                    onPressed: _finishing ? null : _continueToClubs,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text('Continue · $count selected'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final Interest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = interest.accent;
    const radius = BorderRadius.all(Radius.circular(16));
    return Semantics(
      button: true,
      selected: selected,
      label: interest.name,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: MapPatchPainter(accent)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Column(
                  children: [
                    Expanded(
                      child: FittedBox(
                        child: AnimatedSlide(
                          // Lifts off the map when picked up.
                          offset: Offset(0, selected ? -0.06 : 0),
                          duration: const Duration(milliseconds: 150),
                          child: InterestPin(interest, height: 72),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      interest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? accent.deep : McMapColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? accent.deep
                          : accent.deep.withValues(alpha: 0.18),
                      width: selected ? 3 : 1,
                    ),
                    borderRadius: radius,
                  ),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.all(6),
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const CircleAvatar(
                      radius: 11,
                      backgroundColor: McMapColors.red,
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: McMapColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
