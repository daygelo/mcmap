import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class Interest {
  const Interest(this.name, this.icon, this.accent);

  final String name;
  final IconData icon;
  final McMapAccent accent;
}

/// Options shown on the interests page. Edit freely.
const List<Interest> allInterests = [
  Interest('Sports', Icons.sports_hockey_rounded, McMapAccent.lake),
  Interest('Fitness', Icons.fitness_center_rounded, McMapAccent.clay),
  Interest('Music', Icons.headphones_rounded, McMapAccent.heather),
  Interest('Art', Icons.brush_rounded, McMapAccent.plum),
  Interest('Photography', Icons.photo_camera_rounded, McMapAccent.stone),
  Interest('Gaming', Icons.sports_esports_rounded, McMapAccent.sky),
  Interest('Tech', Icons.smart_toy_rounded, McMapAccent.spruce),
  Interest('Coding', Icons.terminal_rounded, McMapAccent.pine),
  Interest('Startups', Icons.lightbulb_rounded, McMapAccent.amber),
  Interest('Food', Icons.ramen_dining_rounded, McMapAccent.clay),
  Interest('Coffee', Icons.local_cafe_rounded, McMapAccent.amber),
  Interest('Travel', Icons.explore_rounded, McMapAccent.lake),
  Interest('Outdoors', Icons.forest_rounded, McMapAccent.pine),
  Interest('Movies', Icons.theaters_rounded, McMapAccent.stone),
  Interest('Reading', Icons.auto_stories_rounded, McMapAccent.moss),
  Interest('Fashion', Icons.checkroom_rounded, McMapAccent.plum),
  Interest('Dance', Icons.sports_gymnastics_rounded, McMapAccent.heather),
  Interest('Volunteering', Icons.volunteer_activism_rounded, McMapAccent.moss),
  Interest('Research', Icons.biotech_rounded, McMapAccent.spruce),
  Interest('Debate', Icons.record_voice_over_rounded, McMapAccent.sky),
  Interest('Culture', Icons.theater_comedy_rounded, McMapAccent.amber),
  Interest('Faith', Icons.self_improvement_rounded, McMapAccent.moss),
  Interest('Parties', Icons.celebration_rounded, McMapAccent.plum),
  Interest('Study Groups', Icons.local_library_rounded, McMapAccent.sky),
];

final interestsByName = Map<String, Interest>.unmodifiable({
  for (final interest in allInterests) interest.name: interest,
});
