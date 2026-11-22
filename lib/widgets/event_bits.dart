import 'package:material_ui/material_ui.dart';

import '../models/club_event.dart';

/// "Tuesday, November 25, 2026 · 6:00 PM" when the date is known, otherwise
/// the organizer's free-text schedule.
String formatEventSchedule(BuildContext context, ClubEvent event) {
  final start = event.startsAt?.toLocal();
  if (start == null) return event.schedule;
  final l10n = MaterialLocalizations.of(context);
  String dateTime(DateTime value) =>
      '${l10n.formatFullDate(value)} · '
      '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  final end = event.endsAt?.toLocal();
  if (end == null) return dateTime(start);
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  final endLabel = sameDay
      ? l10n.formatTimeOfDay(TimeOfDay.fromDateTime(end))
      : dateTime(end);
  return '${dateTime(start)} – $endLabel';
}

/// Shows the event synopsis or an excerpt from the full description.
class EventSynopsis extends StatelessWidget {
  const EventSynopsis({super.key, required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final synopsis = event.synopsis?.trim();
    if (synopsis != null && synopsis.isNotEmpty) {
      return Text(synopsis, style: text.bodyMedium);
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
