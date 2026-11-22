import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/academics.dart';
import '../data/campus_groups.dart';
import '../data/clubs.dart';
import '../models/club_event.dart';
import '../models/student_visibility.dart';
import '../models/user_profile.dart';
import '../pages/student/student_profile.dart';
import '../social/social_graph.dart';
import 'mcmap_backend.dart';
import 'organizer_backend.dart';

/// [McMapBackend] on Supabase. Table and column names match
/// supabase/migrations/20261121000100_mcmap_schema.sql.
class SupabaseBackend implements McMapBackend, OrganizerBackend {
  SupabaseBackend(this.client);

  final SupabaseClient client;
  final _profileRevision = ValueNotifier(0);
  final _onboardingSessionFollows = <String, Map<String, DateTime?>>{};

  @override
  ValueListenable<int> get profileRevision => _profileRevision;

  String get _uid {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Not signed in.');
    return id;
  }

  // -------------------------------------------------------------------------
  // Profile & onboarding
  // -------------------------------------------------------------------------

  @override
  Future<AccountProfile> loadMyProfile() async {
    final row = await client.from('profiles').select().eq('id', _uid).single();
    return _account(row);
  }

  @override
  Future<void> completeOnboarding(UserProfile profile) async {
    final uid = _uid;
    final state = await client.from('profiles').select().eq('id', uid).single();
    if (state['onboarding_completed'] == true &&
        (state['account_purpose'] != 'organizer' ||
            state['degree_level'] != null)) {
      return;
    }

    Map<String, DateTime?>? sessionFollows;
    if (profile.followedClubIds.isNotEmpty) {
      try {
        await client.rpc<void>(
          'change_organization_follows',
          params: {'follow_ids': profile.followedClubIds.toList()},
        );
      } on PostgrestException catch (error) {
        if (!isMissingOrganizationFollowsTable(error) &&
            !_isMissingChangeFollowsFunction(error)) {
          rethrow;
        }
        sessionFollows = {for (final id in profile.followedClubIds) id: null};
        try {
          sessionFollows.addAll(await fetchOrganizationFollows());
        } on OrganizationFollowsUnavailable {
          // The new account can finish onboarding with session-only follows.
        }
      }
    }
    await client
        .from('profiles')
        .update({
          ..._academicColumns(
            profile.degreeLevel,
            profile.year,
            profile.firstYearAtMcGill,
          ),
          'faculty': profile.faculty,
          'major': profile.major,
          'interests': profile.interests.toList(),
          'onboarding_completed': true,
        })
        .eq('id', uid);
    if (sessionFollows != null) _onboardingSessionFollows[uid] = sessionFollows;
    _profileRevision.value++;
  }

  @override
  Future<Map<String, DateTime?>> fetchOrganizationFollows() async {
    final uid = _uid;
    if (_onboardingSessionFollows.containsKey(uid)) {
      throw const OrganizationFollowsUnavailable();
    }
    final List<Map<String, dynamic>> rows;
    try {
      rows = await client
          .from('profile_organization_follows')
          .select('follows')
          .eq('profile_id', uid);
    } on PostgrestException catch (error) {
      if (isMissingOrganizationFollowsTable(error)) {
        throw const OrganizationFollowsUnavailable();
      }
      rethrow;
    }
    final follows =
        rows.firstOrNull?['follows'] as Map<String, dynamic>? ?? const {};
    return {
      for (final entry in follows.entries)
        entry.key: switch (entry.value) {
          {'auto_rsvp_enabled_at': final String value} => DateTime.tryParse(
            value,
          ),
          _ => null,
        },
    };
  }

  @visibleForTesting
  static bool isMissingOrganizationFollowsTable(PostgrestException error) =>
      switch (error.code) {
        'PGRST205' => error.message.contains(
          "Could not find the table 'public.profile_organization_follows'",
        ),
        '42P01' => error.message.contains(
          'relation "public.profile_organization_follows" does not exist',
        ),
        _ => false,
      };

  bool _isMissingChangeFollowsFunction(PostgrestException error) =>
      error.code == 'PGRST202' &&
      error.message.startsWith(
        'Could not find the function public.change_organization_follows(',
      );

  @override
  Future<void> setOrganizationFollow(String id, bool following) =>
      client.rpc<void>(
        'change_organization_follows',
        params: {
          'follow_ids': following ? [id] : <String>[],
          if (!following) 'unfollow_id': id,
        },
      );

  @override
  Future<DateTime?> setOrganizationAutoRsvp(String id, bool enabled) async {
    final consent = await client.rpc<String?>(
      'set_organization_auto_rsvp',
      params: {'group_slug': id, 'enabled': enabled},
    );
    return consent == null ? null : DateTime.parse(consent);
  }

  @override
  Future<Map<String, CampusGroup>> fetchOrganizations() async {
    const pageSize = 500;
    final groups = <String, CampusGroup>{};
    for (var offset = 0; ; offset += pageSize) {
      // All columns: naming short_name/handle would fail on a database that
      // hasn't run the group details migration yet.
      final rows = await client
          .from('groups')
          .select()
          .order('slug')
          .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        groups[row['slug'] as String] = CampusGroup.fromRow(row);
      }
      if (rows.length < pageSize) return groups;
    }
  }

  @override
  Future<List<CampusGroup>> fetchOrganizerDirectory() async =>
      (await fetchOrganizations()).values
          .where((group) => group.uuid != null)
          .toList();

  @override
  Future<List<OrganizerApplication>> fetchOrganizerApplications() async {
    final rows = await client
        .from('organizer_applications')
        .select(
          'id, group_id, full_name, executive_email, role, status, review_note, groups!inner(name)',
        )
        .eq('profile_id', _uid)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        OrganizerApplication(
          id: row['id'] as String,
          details: (
            groupId: row['group_id'] as String,
            fullName: row['full_name'] as String,
            email: row['executive_email'] as String,
            role: ExecutiveRole.values.firstWhere(
              (role) => role.dbValue == row['role'],
            ),
          ),
          organization: row['groups']['name'] as String,
          status: OrganizerStatus.values.firstWhere(
            (status) => status.dbValue == row['status'],
          ),
          reviewNote: row['review_note'] as String?,
        ),
    ];
  }

  @override
  Future<String> sendExecutiveCode(ExecutiveDetails details) async {
    final result = await _organizerVerification({
      'action': 'send',
      'group_id': details.groupId,
      'email': details.email,
      'role': details.role.dbValue,
      'full_name': details.fullName,
    });
    return result['id'] as String;
  }

  @override
  Future<void> verifyExecutiveCode({
    required String applicationId,
    required String groupId,
    required String code,
  }) async {
    await _organizerVerification({
      'action': 'verify',
      'id': applicationId,
      'group_id': groupId,
      'code': code,
    });
  }

  Future<Map<String, dynamic>> _organizerVerification(
    Map<String, String> body,
  ) async {
    final token = client.auth.currentSession?.accessToken;
    if (token == null) {
      throw const OrganizerRequestError(
        'Sign in again to verify your executive email.',
      );
    }
    final Map<String, dynamic> result;
    try {
      final response = await client.functions.invoke(
        'organizer-verification',
        headers: {'Authorization': 'Bearer $token'},
        body: body,
      );
      result = response.data as Map<String, dynamic>;
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw const OrganizerRequestError(
          'Sign in again to verify your executive email.',
        );
      }
      throw const OrganizerRequestError(
        'Verification is unavailable. Try again later.',
      );
    }
    final status = result['status'];
    if (status == 'code_sent' ||
        status == 'approved' ||
        status == 'pending_review') {
      return result;
    }
    throw OrganizerRequestError(switch (status) {
      'invalid_details' => 'Check the executive email and application details.',
      'already_submitted' => 'An active application exists for this organization. Refresh to see its status.',
      'rate_limited' => 'Sending is limited to once per minute and five times per day. Try again later.',
      'delivery_failed' =>
        'The code could not be emailed. Wait a minute and try again.',
      'invalid_code' =>
        'That code is incorrect. Check the email and try again.',
      'expired' => 'That code has expired. Request a new code.',
      'attempts_exhausted' =>
        'Too many incorrect attempts. Request a new code.',
      _ => 'Verification is unavailable. Refresh and try again.',
    });
  }

  @override
  Future<void> requestOrganization(String name, OrganizerCategory category) =>
      client.rpc<void>(
        'organizer_request_directory_review',
        params: {'requested_name': name, 'requested_type': category.name},
      );

  @override
  Future<void> completeOrganizerOnboarding() async {
    await client
        .from('profiles')
        .update({'account_purpose': 'organizer', 'onboarding_completed': true})
        .eq('id', _uid)
        .eq('onboarding_completed', false);
    _profileRevision.value++;
  }

  @override
  Future<void> updateProfile(StudentProfile profile) async {
    final (degree, year) = standingToDb(profile.year);
    await client
        .from('profiles')
        .update({
          'full_name': profile.name,
          'bio': profile.bio,
          if (profile.faculty.isNotEmpty) ...{
            ..._academicColumns(degree, year, profile.firstYearAtMcGill),
            'faculty': profile.faculty,
            'major': profile.major.isEmpty ? null : profile.major,
          },
          'interests': profile.interests.toList(),
        })
        .eq('id', _uid);
  }

  Map<String, Object?> _academicColumns(
    DegreeLevel degree,
    String? year,
    bool firstYear,
  ) => {
    'degree_level': degreeLevelDbValues[degree],
    'u_year': degree.hasUYear ? uYearToDb(year) : null,
    // The database only allows this flag on U1s.
    'is_first_year_u1': year == 'U1' && firstYear,
  };

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    final uid = _uid;
    final (extension, contentType) = _imageType(bytes);
    // A new file name each time, so cached old photos don't linger.
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    final url = client.storage.from('avatars').getPublicUrl(path);
    await client.from('profiles').update({'avatar_url': url}).eq('id', uid);
    return url;
  }

  @override
  Future<void> removeAvatar() async {
    await client.from('profiles').update({'avatar_url': null}).eq('id', _uid);
  }

  // -------------------------------------------------------------------------
  // Events & RSVPs
  // -------------------------------------------------------------------------

  static const _eventColumns = '*, groups(slug, name, avatar_url, type)';

  @override
  Future<List<ClubEvent>> fetchEvents() async {
    const pageSize = 500;
    final events = <ClubEvent>[];
    for (var offset = 0; ; offset += pageSize) {
      final rows = await client
          .from('events')
          .select(_eventColumns)
          .order('starts_at', ascending: true, nullsFirst: false)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      events.addAll(rows.map(_event));
      if (rows.length < pageSize) return events;
    }
  }

  @override
  Future<List<PublishingGroup>> fetchPublishingGroups() async {
    final rows = await client
        .from('group_publishers')
        .select('group_id, groups!inner(name)')
        .eq('profile_id', _uid);
    return [
      for (final row in rows)
        PublishingGroup(
          id: row['group_id'] as String,
          name: row['groups']['name'] as String,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<ClubEvent> publishEvent({
    required String eventId,
    required String groupId,
    required String title,
    required String description,
    required DateTime startsAt,
    DateTime? endsAt,
    required String location,
  }) async {
    final row = await client.rpc<Map<String, dynamic>>(
      'publish_event',
      params: {
        'event_id': eventId,
        'organization_id': groupId,
        'event_title': title,
        'event_description': description,
        'event_start': startsAt.toUtc().toIso8601String(),
        'event_end': endsAt?.toUtc().toIso8601String(),
        'event_location': location,
      },
    );
    return _event(row);
  }

  @override
  Future<Map<String, StudentVisibility>> fetchMyRsvps() async {
    final rows = await client
        .from('event_rsvps')
        .select('event_id, visibility')
        .eq('profile_id', _uid);
    return {
      for (final row in rows)
        row['event_id'] as String: visibilityFromDb(row['visibility']),
    };
  }

  @override
  Future<void> setRsvp(String eventId, StudentVisibility? visibility) async {
    if (visibility == null) {
      await client
          .from('event_rsvps')
          .delete()
          .eq('event_id', eventId)
          .eq('profile_id', _uid);
    } else {
      await client.from('event_rsvps').upsert({
        'event_id': eventId,
        'profile_id': _uid,
        'visibility': visibilityToDb(visibility),
      });
    }
  }

  // -------------------------------------------------------------------------
  // McGillians
  // -------------------------------------------------------------------------

  @override
  Future<List<McGillian>> searchMcGillians(String query) async {
    final rows = await client.rpc(
      'search_mcgillians',
      params: {'q': query, 'max_results': 20},
    );
    return [for (final row in rows as List) _mcgillian(row)];
  }

  @override
  Future<List<(McGillian, FriendStatus)>> fetchMyConnections() async {
    final rows = await client
        .from('mcgillians')
        .select('status, profile:profiles!mcgillians_following_id_fkey(*)')
        .eq('follower_id', _uid);
    return [
      for (final row in rows)
        (_mcgillian(row['profile'] as Map), _status(row['status'])),
    ];
  }

  @override
  Future<FriendStatus> addMcGillian(String profileId) async {
    final row = await client
        .from('mcgillians')
        .insert({'follower_id': _uid, 'following_id': profileId})
        .select('status')
        .single();
    return _status(row['status']);
  }

  @override
  Future<void> removeMcGillian(String profileId) async {
    await client
        .from('mcgillians')
        .delete()
        .eq('follower_id', _uid)
        .eq('following_id', profileId);
  }

  @override
  Future<void> signOut() async {
    final id = client.auth.currentUser?.id;
    await client.auth.signOut();
    _onboardingSessionFollows.remove(id);
  }

  // -------------------------------------------------------------------------
  // Row → model
  // -------------------------------------------------------------------------

  AccountProfile _account(Map<String, dynamic> row) {
    final degree = degreeLevelFromDb(row['degree_level']);
    final faculty = row['faculty'] as String?;
    final done = row['onboarding_completed'] == true;
    final sessionFollows = _onboardingSessionFollows[row['id']];
    return AccountProfile(
      id: row['id'] as String,
      handle: row['handle'] as String,
      fullName: row['full_name'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String? ?? '',
      onboardingCompleted: done,
      academics: !done || degree == null || faculty == null
          ? null
          : UserProfile(
              degreeLevel: degree,
              year: uYearFromDb(row['u_year']),
              firstYearAtMcGill: row['is_first_year_u1'] == true,
              faculty: faculty,
              major: row['major'] as String?,
              followedClubIds: sessionFollows?.keys.toSet() ?? const {},
              clubAutoRsvpOptIns: {
                if (sessionFollows != null)
                  for (final entry in sessionFollows.entries)
                    entry.key: ?entry.value,
              },
              interests: Set.unmodifiable(
                (row['interests'] as List? ?? const []).cast<String>(),
              ),
            ),
    );
  }

  ClubEvent _event(Map<String, dynamic> row) {
    final group = row['groups'] as Map<String, dynamic>?;
    DateTime? time(String key) =>
        row[key] == null ? null : DateTime.parse(row[key] as String);
    double? number(String key) => (row[key] as num?)?.toDouble();
    return ClubEvent(
      row['id'] as String,
      row['title'] as String,
      group?['name'] as String? ?? '',
      row['schedule_label'] as String? ?? '',
      row['location_name'] as String? ?? '',
      clubId: group?['slug'] as String?,
      clubAvatarUrl: group?['avatar_url'] as String?,
      clubType: OrganizationType.fromDb(group?['type']),
      isFrosh: row['is_froshie_event'] == true,
      publishedAt: time('published_at'),
      createdAt: time('created_at'),
      startsAt: time('starts_at'),
      endsAt: time('ends_at'),
      description: row['full_description'] as String?,
      synopsis: row['ai_synopsis'] as String?,
      latitude: number('latitude'),
      longitude: number('longitude'),
      tags: (row['tags'] as List? ?? const []).cast<String>(),
      cancelled: row['cancelled'] == true,
      supportsUnrestrictedRsvp: row['supports_unrestricted_rsvp'] == true,
    );
  }

  McGillian _mcgillian(Map row) {
    final degree = degreeLevelFromDb(row['degree_level']);
    final year = uYearFromDb(row['u_year']);
    return McGillian(
      id: row['id'] as String,
      name: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? row['full_name'] as String
          : 'McMap Student',
      handle: row['handle'] as String,
      faculty: row['faculty'] as String? ?? '',
      major: row['major'] as String? ?? '',
      year: year ?? degree?.shortLabel ?? '',
      firstYearAtMcGill: row['is_first_year_u1'] == true,
      isPrivate: row['is_private'] == true,
      bio: row['bio'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      mcgilliansCount: (row['mcgillians_count'] as num?)?.toInt() ?? 0,
      eventsCount: (row['events_count'] as num?)?.toInt() ?? 0,
      clubsCount: (row['clubs_count'] as num?)?.toInt() ?? 0,
    );
  }

  FriendStatus _status(Object? value) =>
      value == 'requested' ? FriendStatus.requested : FriendStatus.following;

  /// Sniffs JPEG / PNG / WebP from the file header.
  (String, String) _imageType(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return ('png', 'image/png');
    }
    if (bytes.length > 11 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45) {
      return ('webp', 'image/webp');
    }
    return ('jpg', 'image/jpeg');
  }
}
