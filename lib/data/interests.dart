import 'package:material_ui/material_ui.dart';

class Interest {
  const Interest(this.name, this.icon, this.color);

  final String name;
  final IconData icon;
  final Color color;
}

/// Options shown on the interests page. Edit freely.
const List<Interest> allInterests = [
  Interest('Sports', Icons.sports_basketball_rounded, Color(0xFFE76F51)),
  Interest('Fitness', Icons.fitness_center_rounded, Color(0xFFD62828)),
  Interest('Music', Icons.music_note_rounded, Color(0xFF8E44AD)),
  Interest('Art', Icons.palette_rounded, Color(0xFFE91E63)),
  Interest('Photography', Icons.photo_camera_rounded, Color(0xFF455A64)),
  Interest('Gaming', Icons.sports_esports_rounded, Color(0xFF5E35B1)),
  Interest('Tech', Icons.memory_rounded, Color(0xFF1E88E5)),
  Interest('Coding', Icons.code_rounded, Color(0xFF00897B)),
  Interest('Startups', Icons.rocket_launch_rounded, Color(0xFFF4A261)),
  Interest('Food', Icons.restaurant_rounded, Color(0xFFEF6C00)),
  Interest('Coffee', Icons.coffee_rounded, Color(0xFF6D4C41)),
  Interest('Travel', Icons.flight_takeoff_rounded, Color(0xFF0097A7)),
  Interest('Outdoors', Icons.hiking_rounded, Color(0xFF2E7D32)),
  Interest('Movies', Icons.movie_rounded, Color(0xFF37474F)),
  Interest('Reading', Icons.menu_book_rounded, Color(0xFF795548)),
  Interest('Fashion', Icons.checkroom_rounded, Color(0xFFC2185B)),
  Interest('Dance', Icons.nightlife_rounded, Color(0xFFAB47BC)),
  Interest('Volunteering', Icons.volunteer_activism_rounded, Color(0xFF43A047)),
  Interest('Research', Icons.science_rounded, Color(0xFF3949AB)),
  Interest('Debate', Icons.forum_rounded, Color(0xFF546E7A)),
  Interest('Culture', Icons.public_rounded, Color(0xFF00796B)),
  Interest('Faith', Icons.self_improvement_rounded, Color(0xFF7CB342)),
  Interest('Parties', Icons.celebration_rounded, Color(0xFFFF7043)),
  Interest('Study Groups', Icons.groups_rounded, Color(0xFF1F5A75)),
];
