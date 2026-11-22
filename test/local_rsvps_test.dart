import 'package:mcmap/data/academics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/services/local_rsvps.dart';

void main() {
  test('directory has unique IDs and verified aliases', () {
    expect(clubsById.length, clubCatalog.length);
    expect(
      clubCatalog.where((club) => club.type == OrganizationType.club).length,
      greaterThan(250),
    );
    for (final club in clubCatalog) {
      expect(
        club.sourceUrls.every((url) => url.startsWith('https://')),
        isTrue,
      );
    }
    expect(
      clubCatalog
          .where((club) => club.matches(normalizeClubSearch('MESA')))
          .map((club) => club.id),
      contains('ssmu-mcgill-e-sports-students-society'),
    );
  });

  test('verified first-year organizations have distinct IDs and searchable aliases', () {
    const groups = {
      'SSMU FYC': 'ssmu-first-year-council',
      'Engineering Junior Council': 'eus-junior-council',
      'AUS FEARC': 'aus-fearc',
      'SUS First-Year Council': 'sus-fuss',
      'CSUS FYC': 'csus-first-year-council',
      'ECSESS Bits': 'ecsess-bits',
      'BUSS FYC': 'buss-first-year-council',
      'MAME FYC': 'mame-first-year-council',
      'MUS FIT': 'mus-first-year-involvement-team',
      'EdUS FYRE': 'edus-fyre',
      'PSSA FYC': 'pssa-first-year-council',
    };
    for (final entry in groups.entries) {
      final matches = searchClubCatalog(entry.key);
      final match = matches.first;
      expect(match.id, entry.value, reason: entry.key);
      expect(matches.where((club) => club.id == entry.value), hasLength(1));
      expect(
        match.type,
        isIn([
          OrganizationType.firstYearCouncil,
          OrganizationType.firstYearCommittee,
          OrganizationType.firstYearSociety,
        ]),
      );
    }
  });

  test('only new eligible events RSVP, publicly and once per event ID', () {
    final now = DateTime.utc(2026, 11, 21, 12);
    final enabledAt = now.subtract(const Duration(hours: 1));
    final profile = UserProfile(
      degreeLevel: DegreeLevel.undergraduate,
      faculty: 'Engineering',
      major: 'Software Engineering',
      year: 'U2',
      followedClubIds: const {'selected'},
      clubAutoRsvpOptIns: {'selected': enabledAt},
    );
    final rsvps = LocalRsvps();

    ClubEvent event(
      String id, {
      String? clubId = 'selected',
      DateTime? publishedAt,
      DateTime? startsAt,
      bool cancelled = false,
      bool eligible = true,
    }) => ClubEvent(
      id,
      id,
      'Club',
      'Tomorrow',
      'Campus',
      clubId: clubId,
      publishedAt: publishedAt ?? now,
      startsAt: startsAt ?? now.add(const Duration(days: 1)),
      cancelled: cancelled,
      supportsUnrestrictedRsvp: eligible,
    );

    for (final skipped in [
      event('unrelated', clubId: 'other'),
      event('unlinked', clubId: null),
      event('restricted', eligible: false),
      event('past', startsAt: now),
      event('cancelled', cancelled: true),
      event('previous', publishedAt: enabledAt),
      event('scheduled', publishedAt: now.add(const Duration(minutes: 1))),
      const ClubEvent(
        'unpublished',
        'Draft',
        'Club',
        'Tomorrow',
        'Campus',
        clubId: 'selected',
        supportsUnrestrictedRsvp: true,
      ),
    ]) {
      rsvps.onPublished(skipped, profile, now: now);
      expect(rsvps.visibilityFor(skipped.id), isNull, reason: skipped.id);
    }

    rsvps.toggle('manual', StudentVisibility.friends);
    rsvps.onPublished(event('manual'), profile, now: now);
    expect(rsvps.visibilityFor('manual'), StudentVisibility.friends);

    final eligible = event('new');
    rsvps.onPublished(eligible, profile, now: now);
    rsvps.onPublished(eligible, profile, now: now);
    expect(rsvps.visibilityFor(eligible.id), StudentVisibility.public);

    final disabled = profile.copyWith(clubAutoRsvpOptIns: {});
    rsvps.onPublished(event('disabled'), disabled, now: now);
    expect(rsvps.visibilityFor('disabled'), isNull);
    expect(rsvps.visibilityFor(eligible.id), StudentVisibility.public);

    rsvps.toggle(eligible.id, StudentVisibility.public);
    rsvps.onPublished(eligible, profile, now: now);
    expect(rsvps.visibilityFor(eligible.id), isNull);
    rsvps.toggle(eligible.id, StudentVisibility.public);
    rsvps.onPublished(eligible, profile, now: now);
    expect(rsvps.visibilityFor(eligible.id), StudentVisibility.public);

    rsvps.onPublished(
      event('removed'),
      profile.copyWith(followedClubIds: {}),
      now: now,
    );
    expect(rsvps.visibilityFor('removed'), isNull);
    expect(rsvps.visibilityFor(eligible.id), StudentVisibility.public);
  });
}
