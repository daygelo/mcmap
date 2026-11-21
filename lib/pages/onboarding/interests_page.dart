import 'package:material_ui/material_ui.dart';

import '../../data/interests.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../home_page.dart';

/// Onboarding step 2 (optional): Instagram-style grid of interests to tap.
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

  void _toggle(String name) {
    setState(() {
      if (!_selected.remove(name)) _selected.add(name);
    });
  }

  void _finish() {
    // An empty set is valid: the feed falls back to faculty + general events.
    final profile = widget.profile.copyWith(interests: Set.of(_selected));
    // Onboarding is done: replace the whole stack so Back doesn't return here.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomePage(profile: profile)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _selected.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Step 2 of 2')),
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
                    onPressed: _finish,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Skip for now'),
                  )
                : FilledButton(
                    key: const ValueKey('continue'),
                    onPressed: _finish,
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
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Semantics(
      button: true,
      selected: selected,
      label: interest.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 0.94 : 1,
          duration: const Duration(milliseconds: 150),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    // Category colors are specific to these tiles. Darken
                    // the label area for contrast across the whole palette.
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0, 0.45, 1],
                      colors: [
                        interest.color,
                        Color.lerp(interest.color, McMapColors.ink, 0.25)!,
                        Color.lerp(interest.color, McMapColors.ink, 0.75)!,
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    interest.icon,
                    size: 44,
                    color: McMapColors.white.withValues(alpha: 0.9),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    interest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle?.copyWith(
                      color: McMapColors.white,
                      shadows: [Shadow(blurRadius: 6, color: McMapColors.ink)],
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: McMapColors.ink.withValues(alpha: 0.35),
                      border: Border.all(color: McMapColors.white, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: McMapColors.red,
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: McMapColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
