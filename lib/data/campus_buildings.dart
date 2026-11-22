import 'dart:convert';

import 'campus_building_shapes.dart';
import 'sight_line.dart';

enum SpaceType {
  facultyOffice('Faculty Office'),
  studentLounge('Student Lounge'),
  campusSociety('Campus Society');

  const SpaceType(this.label);
  final String label;
}

/// What a highlighted building is for, worked out from its spaces.
enum BuildingCategory {
  ssmu('SSMU Building'),
  facultyOffice('Faculty office'),
  mixed('Faculty office & lounge'),
  lounge('Student lounge');

  const BuildingCategory(this.label);
  final String label;
}

/// Map colours. [selected] is a darker shade of [color].
enum BuildingHighlight {
  ssmu('SSMU', 0xED1B2F, 0x9E0B0F),
  engineering('Engineering', 0x2563EB, 0x1E3A8A),
  arts('Arts', 0x6D28D9, 0x4C1D95),
  science('Science', 0x059669, 0x065F46),
  management('Management', 0xD97706, 0x92400E),
  education('Education', 0x0284C7, 0x075985),
  music('Music', 0xDB2777, 0x9D174D),
  law('Law', 0x4D7C0F, 0x365314),
  lounge('Student lounge only', 0x475569, 0x1E293B);

  const BuildingHighlight(this.label, this.color, this.selected);
  final String label;

  /// 0xRRGGBB.
  final int color;
  final int selected;

  bool get isFaculty => this != ssmu && this != lounge;

  /// Halfway to white, for hovering.
  int get hover {
    int channel(int shift) {
      final value = (color >> shift) & 0xFF;
      return (value + ((255 - value) * 0.35).round()) << shift;
    }

    return channel(16) | channel(8) | channel(0);
  }

  static String css(int rgb) => '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

/// An office or lounge inside a building.
class BuildingSpace {
  const BuildingSpace(
    this.name,
    this.type, {
    required this.source,
    this.roomOrFloor,
    this.organization,
    this.clubId,
    this.description,
    this.hours,
  });

  final String name;
  final SpaceType type;

  /// Null when no room is published anywhere we could find.
  final String? roomOrFloor;

  /// Short name such as "EUS", and its page in the club catalog.
  final String? organization;
  final String? clubId;
  final String? description;
  final String? hours;

  /// Where the details come from, for checking them later. Not shown.
  final String source;
}

class CampusBuilding {
  const CampusBuilding({
    required this.id,
    required this.name,
    required this.address,
    required this.highlight,
    required this.spaces,
    this.hours,
  });

  final String id;
  final String name;
  final String address;
  final BuildingHighlight highlight;
  final List<BuildingSpace> spaces;

  /// Opening hours of the whole building.
  final String? hours;

  BuildingCategory get category {
    if (highlight == BuildingHighlight.ssmu) return BuildingCategory.ssmu;
    bool has(SpaceType type) => spaces.any((space) => space.type == type);
    if (!has(SpaceType.facultyOffice)) return BuildingCategory.lounge;
    return has(SpaceType.studentLounge)
        ? BuildingCategory.mixed
        : BuildingCategory.facultyOffice;
  }

  BuildingShape get shape => campusBuildingShapes[id]!;

  /// Shared by every piece of the building, so one state change colours it all.
  int get featureId => campusBuildings.indexOf(this) + 1;
}

/// A building's surveyed shape, as (longitude, latitude).
class BuildingShape {
  BuildingShape._(Map<String, dynamic> json)
    : center = (
        (json['center'][0] as num).toDouble(),
        (json['center'][1] as num).toDouble(),
      ),
      basemapIds = {for (final id in json['osm'] as List) '$id'},
      parts = (json['parts'] as List).cast<Map<String, dynamic>>(),
      outline = json['outline'] as List,
      basemap = json['basemap'] as List;

  final (double, double) center;

  /// Ids of the basemap's own, simpler copy of this building.
  final Set<String> basemapIds;

  /// Each has `base` and `top` heights in metres, and GeoJSON `rings`.
  final List<Map<String, dynamic>> parts;

  /// The footprint on the ground: polygons, each a list of rings.
  final List<dynamic> outline;

  /// Where the basemap draws its own copy, which is removed.
  final List<dynamic> basemap;

  /// How far along [line] this building is, or null if the line misses it.
  double? distanceOn(SightLine line) {
    double? nearest;
    for (final part in parts) {
      final distance = line.distanceTo(
        part['rings'] as List,
        base: (part['base'] as num).toDouble(),
        top: (part['top'] as num).toDouble(),
      );
      if (distance != null && (nearest == null || distance < nearest)) {
        nearest = distance;
      }
    }
    return nearest;
  }
}

final campusBuildingShapes = {
  for (final row in const LineSplitter().convert(
    campusBuildingShapeRows.trim(),
  ))
    if (jsonDecode(row) case final Map<String, dynamic> json)
      json['id'] as String: BuildingShape._(json),
};

final _basemapIds = {
  for (final shape in campusBuildingShapes.values) ...shape.basemapIds,
};

/// Whether a basemap building is a copy of one we draw ourselves: by its id,
/// or because its middle is inside one (towers are sometimes separate).
bool isReplacedBasemapBuilding(Object? id, List<dynamic> rings) {
  if (_basemapIds.contains('$id')) return true;
  if (rings.isEmpty) return false;
  final corners = (rings.first as List).cast<List<dynamic>>();
  double middle(int axis) =>
      corners.fold<double>(0, (sum, p) => sum + (p[axis] as num)) /
      corners.length;
  final (x, y) = (middle(0), middle(1));
  return campusBuildingShapes.values.any(
    (shape) => shape.outline.any((polygon) => isInside(x, y, polygon as List)),
  );
}

final campusBuildingsById = {
  for (final building in campusBuildings) building.id: building,
};

Map<String, Object> _collection(Iterable<Map<String, Object>> features) => {
  'type': 'FeatureCollection',
  'features': features.toList(),
};

Map<String, Object> _polygon(
  CampusBuilding building,
  List<dynamic> rings, [
  Map<String, Object> properties = const {},
]) => {
  'type': 'Feature',
  'id': building.featureId,
  'geometry': {'type': 'Polygon', 'coordinates': rings},
  'properties': {
    'building': building.id,
    'color': BuildingHighlight.css(building.highlight.color),
    'hover': BuildingHighlight.css(building.highlight.hover),
    'selected': BuildingHighlight.css(building.highlight.selected),
    ...properties,
  },
};

/// The coloured 3D buildings.
Map<String, Object> campusBuildingCollection() => _collection([
  for (final building in campusBuildings)
    for (final part in building.shape.parts)
      _polygon(building, part['rings'] as List, {
        'base': part['base'] as num,
        'top': part['top'] as num,
      }),
]);

/// Footprints, for the glow.
Map<String, Object> campusOutlineCollection() => _collection([
  for (final building in campusBuildings)
    for (final rings in building.shape.outline)
      _polygon(building, rings as List),
]);

/// Where to remove the basemap's own buildings.
Map<String, Object> campusBasemapCollection() => _collection([
  for (final building in campusBuildings)
    for (final rings in building.shape.basemap)
      _polygon(building, rings as List),
]);

const _ssmu = 'https://ssmu.ca/buildingservices/university-centre';
const _eusLounges =
    'https://euswiki.mcgilleus.ca/eus-spaces/departmental-lounges';
const _musicBuilding =
    'https://www.mcgill.ca/music/about-us/building-resources';
const _msps = 'https://www.msps.physics.mcgill.ca/';
const _pgss = 'https://www.mcgill.ca/foodservices/node/1407';

/// Rooms were checked against [BuildingSpace.source] in November 2026. Student
/// spaces move often: update the room and source together, and leave the room
/// out rather than guess.
const campusBuildings = [
  CampusBuilding(
    id: 'university-centre',
    name: 'University Centre (SSMU)',
    address: '3480 McTavish Street',
    highlight: BuildingHighlight.ssmu,
    hours: 'Fall 2026: Mon–Tue 8:30–22:00, Wed–Fri 8:30–23:00, closed weekends',
    spaces: [
      BuildingSpace(
        'SSMU Office',
        SpaceType.campusSociety,
        organization: 'SSMU',
        clubId: 'mcgill-ssmu',
        roomOrFloor: 'Room 110, 1st floor',
        description: 'Student life, operations and communications.',
        source: _ssmu,
      ),
      BuildingSpace(
        'SSMU Information Kiosk',
        SpaceType.campusSociety,
        organization: 'SSMU',
        clubId: 'mcgill-ssmu',
        roomOrFloor: '1st floor',
        source: _ssmu,
      ),
      BuildingSpace(
        "Students' Lounge",
        SpaceType.studentLounge,
        roomOrFloor: 'Room 106A, 1st floor',
        source: _ssmu,
      ),
      BuildingSpace(
        'Cafeteria seating',
        SpaceType.studentLounge,
        roomOrFloor: 'Room 201a, 2nd floor',
        source: _ssmu,
      ),
      BuildingSpace(
        'Club Lounge',
        SpaceType.studentLounge,
        roomOrFloor: 'Room 401',
        source: _ssmu,
      ),
      BuildingSpace(
        'Gerts Café & Bar',
        SpaceType.studentLounge,
        roomOrFloor: 'Café in Room 130, bar in B01 (basement)',
        description: 'It has closed for long periods; check with SSMU first.',
        source: _ssmu,
      ),
    ],
  ),
  CampusBuilding(
    id: 'mcconnell',
    name: 'McConnell Engineering Building',
    address: '3480 University Street',
    highlight: BuildingHighlight.engineering,
    spaces: [
      BuildingSpace(
        'EUS Office',
        SpaceType.facultyOffice,
        organization: 'EUS',
        clubId: 'engineering-engineering-undergraduate-society-eus',
        roomOrFloor: 'Room 7',
        description: 'Engineering Undergraduate Society.',
        hours: '9:00–12:00 and 13:00–17:00',
        source: 'https://euswiki.mcgilleus.ca/EUS',
      ),
      BuildingSpace(
        'Engineering Common Room',
        SpaceType.studentLounge,
        organization: 'EUS',
        clubId: 'engineering-engineering-undergraduate-society-eus',
        roomOrFloor: 'Basement, below the EUS Mall',
        description: 'Home of Blues Pub. Engineering student card needed.',
        hours: '8:00–21:00',
        source:
            'https://euswiki.mcgilleus.ca/eus-spaces/engineering-common-room',
      ),
      BuildingSpace(
        'Bioengineering Lounge',
        SpaceType.studentLounge,
        organization: 'BUSS',
        clubId:
            'engineering-bioengineering-undergraduate-students-society-buss',
        roomOrFloor: 'Room 030',
        source: _eusLounges,
      ),
      BuildingSpace(
        'Mechanical Engineering Lounge',
        SpaceType.studentLounge,
        organization: 'MAME',
        clubId: 'engineering-mcgill-association-of-mechanical-engineers-mame',
        roomOrFloor: 'Room 120',
        source: _eusLounges,
      ),
    ],
  ),
  CampusBuilding(
    id: 'leacock',
    name: 'Leacock Building',
    address: '855 Sherbrooke Street West',
    highlight: BuildingHighlight.arts,
    spaces: [
      BuildingSpace(
        'AUS Office',
        SpaceType.facultyOffice,
        organization: 'AUS',
        clubId: 'aus',
        roomOrFloor: 'Room B-12',
        description: 'Arts Undergraduate Society.',
        source: 'https://ssmu.ca/wp-content/uploads/2025/10/SSMU-Arts-Report-Fall-2025-.pdf',
      ),
      BuildingSpace(
        'SNAX',
        SpaceType.studentLounge,
        organization: 'AUS',
        clubId: 'aus',
        description: 'Not-for-profit snack bar run by AUS students.',
        hours: '8:30–18:00',
        source: 'https://mcgill.ca/onecard/where-use/campus-food-drink/snax',
      ),
    ],
  ),
  CampusBuilding(
    id: 'burnside',
    name: 'Burnside Hall',
    address: '805 Sherbrooke Street West',
    highlight: BuildingHighlight.science,
    spaces: [
      BuildingSpace(
        'SUS Office',
        SpaceType.facultyOffice,
        organization: 'SUS',
        clubId: 'sus',
        roomOrFloor: 'Room 1B21, basement',
        description: 'Science Undergraduate Society. Drop-in office hours.',
        source: 'https://susmcgill.ca/contact-us',
      ),
      BuildingSpace(
        'Basement student lounge',
        SpaceType.studentLounge,
        roomOrFloor: 'Basement',
        description: 'Renovated lounge and study space.',
        source: 'https://reporter.mcgill.ca/burnside-hall-basement-transformed-into-student-oasis/',
      ),
    ],
  ),
  CampusBuilding(
    id: 'bronfman',
    name: 'Bronfman Building',
    address: '1001 Sherbrooke Street West',
    highlight: BuildingHighlight.management,
    spaces: [
      BuildingSpace(
        'MUS Office',
        SpaceType.facultyOffice,
        organization: 'MUS',
        clubId: 'desautels-mus',
        roomOrFloor: 'Room 101',
        description: 'Management Undergraduate Society.',
        source: 'https://ssmu.ca/wp-content/uploads/2024/10/Report-Management-MUS-2024-10-03.pdf',
      ),
      BuildingSpace(
        'Undergraduate student areas',
        SpaceType.studentLounge,
        roomOrFloor: 'Concourse and 2nd floor',
        description: 'Student living areas and computer labs.',
        source: 'https://www.mcgill.ca/study/2020-2021/node/698',
      ),
    ],
  ),
  CampusBuilding(
    id: 'education',
    name: 'Education Building',
    address: '3700 McTavish Street',
    highlight: BuildingHighlight.education,
    spaces: [
      BuildingSpace(
        'EdUS Office',
        SpaceType.facultyOffice,
        organization: 'EdUS',
        clubId: 'education-edus',
        roomOrFloor: 'Room B179',
        description: 'Education Undergraduate Society.',
        source:
            'https://www.mcgill.ca/education/community/student-associations',
      ),
      BuildingSpace(
        'Education Lounge',
        SpaceType.studentLounge,
        organization: 'EdUS',
        clubId: 'education-edus',
        description: 'Looked after by EdUS.',
        source:
            'https://www.mcgill.ca/education/community/student-associations',
      ),
    ],
  ),
  CampusBuilding(
    id: 'strathcona-music',
    name: 'Strathcona Music Building',
    address: '555 Sherbrooke Street West',
    highlight: BuildingHighlight.music,
    spaces: [
      BuildingSpace(
        'MUSA',
        SpaceType.facultyOffice,
        organization: 'MUSA',
        clubId: 'music-musa',
        description:
            "Music Undergraduate Students' Association. Ask Schulich Student "
            'Affairs where to find them.',
        source: _musicBuilding,
      ),
      BuildingSpace(
        'Cafeteria',
        SpaceType.studentLounge,
        roomOrFloor: 'Basement',
        source: _musicBuilding,
      ),
    ],
  ),
  CampusBuilding(
    id: 'chancellor-day',
    name: 'Chancellor Day Hall',
    address: '3644 Peel Street',
    highlight: BuildingHighlight.law,
    spaces: [
      BuildingSpace(
        'LSA Office',
        SpaceType.facultyOffice,
        organization: 'LSA',
        clubId: 'law-lsa',
        roomOrFloor: 'Basement, Old Chancellor Day Hall',
        description: "Law Students' Association.",
        source: 'https://coursecatalogue.mcgill.ca/en/undergraduate/law/student-activities-services/association/',
      ),
    ],
  ),
  CampusBuilding(
    id: 'adams',
    name: 'Frank Dawson Adams Building',
    address: '3450 University Street',
    highlight: BuildingHighlight.lounge,
    spaces: [
      BuildingSpace(
        'Mining Lounge',
        SpaceType.studentLounge,
        organization: 'Mining',
        clubId: 'engineering-co-op-mining-engineering-undergraduate-society',
        roomOrFloor: 'Room 108',
        source: _eusLounges,
      ),
    ],
  ),
  CampusBuilding(
    id: 'macdonald-harrington',
    name: 'Macdonald-Harrington Building',
    address: '815 Sherbrooke Street West',
    highlight: BuildingHighlight.lounge,
    spaces: [
      BuildingSpace(
        'Architecture Lounge (The Cellar)',
        SpaceType.studentLounge,
        organization: 'ASA',
        clubId: 'engineering-architecture-students-society-asa',
        roomOrFloor: 'Room G2',
        source: _eusLounges,
      ),
    ],
  ),
  CampusBuilding(
    id: 'macdonald-engineering',
    name: 'Macdonald Engineering Building',
    address: '817 Sherbrooke Street West',
    highlight: BuildingHighlight.lounge,
    spaces: [
      BuildingSpace(
        'Civil Lounge',
        SpaceType.studentLounge,
        organization: 'CEUS',
        clubId: 'engineering-civil-engineering-undergraduate-society-ceus',
        roomOrFloor: 'Room 290',
        source: _eusLounges,
      ),
    ],
  ),
  CampusBuilding(
    id: 'trottier',
    name: 'Trottier Building',
    address: '3630 University Street',
    highlight: BuildingHighlight.lounge,
    spaces: [
      BuildingSpace(
        'ECSESS Lounge',
        SpaceType.studentLounge,
        organization: 'ECSESS',
        clubId: 'engineering-electrical-computer-software-engineering-student-society-ecsess',
        roomOrFloor: 'Room 1060',
        description: 'Electrical, computer and software engineering.',
        source: _eusLounges,
      ),
    ],
  ),
  CampusBuilding(
    id: 'wong',
    name: 'Wong Building',
    address: '3610 University Street',
    highlight: BuildingHighlight.lounge,
    spaces: [
      BuildingSpace(
        'Chem Lounge',
        SpaceType.studentLounge,
        organization: 'ChESS',
        clubId: 'engineering-chemical-engineering-students-society-chess',
        roomOrFloor: 'Room 1130',
        description: 'Chemical engineering.',
        source: _eusLounges,
      ),
      BuildingSpace(
        'Metroom',
        SpaceType.studentLounge,
        organization: 'MEUS',
        clubId: 'engineering-materials-engineering-undergraduate-society-meus',
        roomOrFloor: 'Room 1140',
        description: 'Materials engineering.',
        source: _eusLounges,
      ),
    ],
  ),
  CampusBuilding(
    id: 'rutherford',
    name: 'Rutherford Physics Building',
    address: '3600 University Street',
    highlight: BuildingHighlight.lounge,
    spaces: [
      BuildingSpace(
        'Undergraduate physics lounge',
        SpaceType.studentLounge,
        roomOrFloor: 'Room 117',
        source: _msps,
      ),
      BuildingSpace(
        'MSPS Office',
        SpaceType.campusSociety,
        organization: 'MSPS',
        roomOrFloor: 'Room 119',
        description: 'McGill Society of Physics Students.',
        source: _msps,
      ),
    ],
  ),
  CampusBuilding(
    id: 'thomson-house',
    name: 'Thomson House',
    address: '3650 McTavish Street',
    highlight: BuildingHighlight.lounge,
    spaces: [
      BuildingSpace(
        'PGSS',
        SpaceType.campusSociety,
        organization: 'PGSS',
        clubId: 'mcgill-pgss',
        description:
            "Post-Graduate Students' Society, which runs the building.",
        source: _pgss,
      ),
      BuildingSpace(
        'Thomson House bar and restaurant',
        SpaceType.studentLounge,
        organization: 'PGSS',
        clubId: 'mcgill-pgss',
        source: _pgss,
      ),
    ],
  ),
];
