import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart';

import '../../data/clubs.dart';
import 'club_discovery.dart';

class SuggestedClubs extends StatefulWidget {
  const SuggestedClubs({
    super.key,
    required this.faculty,
    required this.major,
    required this.interests,
    required this.followedClubIds,
    required this.onFollow,
    required this.onOpen,
    required this.onBrowse,
  });

  final String faculty;
  final String? major;
  final Set<String> interests;
  final Set<String> followedClubIds;
  final ValueChanged<String> onFollow;
  final ValueChanged<ClubOrganization> onOpen;
  final VoidCallback onBrowse;

  @override
  State<SuggestedClubs> createState() => _SuggestedClubsState();
}

class _SuggestedClubsState extends State<SuggestedClubs> {
  static const _animationDuration = Duration(milliseconds: 180);
  final _slots = List<ClubOrganization?>.filled(3, null);
  final _confirmations = <String, Timer>{};
  late List<ClubOrganization> _ranked;

  @override
  void initState() {
    super.initState();
    _ranked = _rankClubs(widget);
    _fillSlots();
  }

  @override
  void didUpdateWidget(SuggestedClubs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget;
    final current = widget;
    if (previous.faculty != current.faculty ||
        previous.major != current.major ||
        !setEquals(previous.interests, current.interests)) {
      _ranked = _rankClubs(current);
      for (var index = 0; index < _slots.length; index++) {
        if (!_confirmations.containsKey(_slots[index]?.id)) {
          _slots[index] = null;
        }
      }
    }
    for (final id in _confirmations.keys.toList()) {
      if (!current.followedClubIds.contains(id)) {
        _confirmations.remove(id)?.cancel();
      }
    }
    _fillSlots();
  }

  void _fillSlots() {
    final followed = widget.followedClubIds;
    for (var index = 0; index < _slots.length; index++) {
      final id = _slots[index]?.id;
      if (id != null &&
          followed.contains(id) &&
          !_confirmations.containsKey(id)) {
        _slots[index] = null;
      }
    }
    final occupied = _slots.nonNulls.map((club) => club.id).toSet();
    final candidates = _ranked
        .where(
          (club) => !followed.contains(club.id) && !occupied.contains(club.id),
        )
        .iterator;
    for (var index = 0; index < _slots.length; index++) {
      if (_slots[index] == null && candidates.moveNext()) {
        _slots[index] = candidates.current;
      }
    }
  }

  void _follow(String id) {
    if (widget.followedClubIds.contains(id) || _confirmations.containsKey(id)) {
      return;
    }
    _confirmations[id] = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _confirmations.remove(id);
        _fillSlots();
      });
    });
    widget.onFollow(id);
  }

  @override
  void dispose() {
    for (final timer in _confirmations.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Clubs for you', style: text.titleLarge)),
            TextButton(
              onPressed: widget.onBrowse,
              child: const Text('See all clubs'),
            ),
          ],
        ),
        for (final club in _slots)
          AnimatedSize(
            duration: _animationDuration,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: _animationDuration,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  for (final outgoing in previous)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(child: outgoing),
                      ),
                    ),
                  ?current,
                ],
              ),
              child: club == null
                  ? const SizedBox.shrink()
                  : ClubRow(
                      key: ValueKey(club.id),
                      club: club,
                      compact: true,
                      following: widget.followedClubIds.contains(club.id),
                      onFollow: _confirmations.containsKey(club.id)
                          ? null
                          : () => _follow(club.id),
                      onOpen: () => widget.onOpen(club),
                    ),
            ),
          ),
        if (_slots.every((club) => club == null))
          Text('No more club suggestions right now.', style: text.bodySmall),
      ],
    );
  }
}

// These pair broad interests with published directory categories. A specific
// club gets no inferred tags or affiliations.
const _interestCategories = {
  'sports': {'athletics and recreation', 'recreation'},
  'fitness': {'athletics and recreation', 'recreation'},
  'volunteering': {'community outreach and volunteering'},
  'art': {'fine arts, dance and performance'},
  'dance': {'fine arts, dance and performance'},
  'reading': {'language and publications'},
};

List<ClubOrganization> _rankClubs(SuggestedClubs profile) {
  final interests = profile.interests.map(normalizeClubSearch);
  final major = normalizeClubSearch(profile.major ?? '');
  final faculty = normalizeClubSearch(profile.faculty)
      .replaceFirst('faculty of ', '');
  final ranked = <(ClubOrganization, int, int)>[];
  final firstByCategory = <String>{};
  final fallback = <ClubOrganization>[];
  final remaining = <ClubOrganization>[];

  for (final (index, club) in clubCatalog.indexed) {
    final category = normalizeClubSearch(club.category);
    final metadata = [club.name, ...club.aliases, club.category]
        .map(
          (value) =>
              ' ${normalizeClubSearch(value).replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ',
        )
        .toList();
    bool matches(String phrase) =>
        phrase.isNotEmpty &&
        metadata.any((value) => value.contains(' $phrase '));

    final interestMatches = interests
        .where(
          (interest) =>
              matches(interest) ||
              (_interestCategories[interest]?.contains(category) ?? false),
        )
        .length;
    final facultyMatch =
        matches(faculty) ||
        (faculty.contains('management') && category == 'desautels');
    final score =
        interestMatches * 100 +
        (matches(major) ? 10 : 0) +
        (facultyMatch ? 1 : 0);
    if (score > 0) {
      ranked.add((club, score, index));
    } else if (firstByCategory.add(category)) {
      fallback.add(club);
    } else {
      remaining.add(club);
    }
  }
  ranked.sort((a, b) {
    final scoreOrder = b.$2.compareTo(a.$2);
    return scoreOrder == 0 ? a.$3.compareTo(b.$3) : scoreOrder;
  });
  return [...ranked.map((entry) => entry.$1), ...fallback, ...remaining];
}
