import 'package:material_ui/material_ui.dart';

import '../models/club_event.dart';
import '../theme/app_theme.dart';

/// "Tuesday, November 25, 2026 · 6:00 PM" when the date is known, otherwise
/// the organizer's free-text schedule.
String formatEventSchedule(BuildContext context, ClubEvent event) {
  final start = event.startsAt?.toLocal();
  if (start == null) return event.schedule;
  final l10n = MaterialLocalizations.of(context);
  return '${l10n.formatFullDate(start)} · '
      '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(start))}';
}

/// The short summary on a feed card. Shows the AI synopsis with a small
/// "AI Summary" label; without one, falls back to the start of the full
/// description (no AI label, since nothing was generated).
class EventSynopsis extends StatelessWidget {
  const EventSynopsis({super.key, required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final synopsis = event.synopsis?.trim();
    if (synopsis != null && synopsis.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: McMapColors.slate,
              ),
              const SizedBox(width: 4),
              Text(
                'AI SUMMARY',
                style: text.labelSmall?.copyWith(
                  color: McMapColors.slate,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(synopsis, style: text.bodyMedium),
        ],
      );
    }
    final description = event.description?.trim();
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: text.bodyMedium,
    );
  }
}
