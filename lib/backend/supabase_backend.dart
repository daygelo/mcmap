import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/academics.dart';
import '../models/club_event.dart';
import '../models/student_visibility.dart';
import '../models/user_profile.dart';
import '../pages/student/student_profile.dart';
import '../social/social_graph.dart';
import 'mcmap_backend.dart';

/// [McMapBackend] on Supabase. Table and column names match
/// supabase/migrations/20261121000100_mcmap_schema.sql.
class SupabaseBackend implements McMapBackend {
  SupabaseBackend(this.client);

  final SupabaseClient client;
  final _profileRevision = ValueNotifier(0);

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
    try {
      final uid = _uid;
      var row = await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row == null) {
        // E.g. an account created before the profiles table existed. Create
        // a starter row (onboarding_completed = false) → onboarding.
        debugPrint('McMap: no profiles row for $uid yet; creating one.');
        row = Map<String, dynamic>.from(
          await client.rpc('ensure_my_profile') as Map,
        );
      }
      final (followed, optIns, memberships) = await _loadClubs(uid);
      return _account(
        row,
        followed: followed,
        optIns: optIns,
        memberships: memberships,
      );
    } catch (error, stack) {
      final problem = describeLoadError(error);
      debugPrint('McMap: loading the profile failed ($problem): $error');
      if (kDebugMode) debugPrint('$stack');
      throw problem;
    }
  }

  /// Club follows and memberships. If those tables aren't set up yet (their
  /// migration hasn't been run), the profile still loads, without clubs.
  Future<(Set<String>, Map<String, DateTime>, Map<String, ClubMembership>)>
  _loadClubs(String uid) async {
    try {
      final (follows, memberships) = await (
        client
            .from('group_follows')
            .select('notifications_enabled_at, groups(id, slug)')
            .eq('profile_id', uid),
        client
            .from('group_memberships')
            .select('show_on_profile, auto_rsvp_enabled_at, groups(id, slug)')
            .eq('profile_id', uid),
      ).wait;
      String slug(Map<String, dynamic> r) {
        final group = r['groups'] as Map<String, dynamic>;
        _groupIds[group['slug'] as String] = group['id'] as String;
        return group['slug'] as String;
      }

      DateTime? time(Object? value) =>
          value == null ? null : DateTime.parse(value as String);
      return (
        {for (final r in follows) slug(r)},
        {
          for (final r in follows)
            slug(r): ?time(r['notifications_enabled_at']),
        },
        {
          for (final r in memberships)
            slug(r): ClubMembership(
              showOnProfile: r['show_on_profile'] == true,
              autoRsvpEnabledAt: time(r['auto_rsvp_enabled_at']),
            ),
        },
      );
    } catch (error) {
      final inner = error is ParallelWaitError ? error.errors : error;
      if (describeLoadError(_firstError(inner)).problem !=
          ProfileLoadProblem.databaseSetup) {
        rethrow;
      }
      debugPrint(
        'McMap: club follows/memberships unavailable (run migration '
        '20261122000100_group_follows_and_auto_follow.sql): $error',
      );
      return (<String>{}, <String, DateTime>{}, <String, ClubMembership>{});
    }
  }

  static Object _firstError(Object error) {
    if (error is ParallelWaitError) return _firstError(error.errors);
    if (error is (AsyncError?, AsyncError?)) {
      return (error.$1 ?? error.$2)?.error ?? error;
    }
    return error;
  }

  /// Sorts a failure into network / signed out / database setup / unknown,
  /// so the app can say what's actually wrong.
  static ProfileLoadException describeLoadError(Object error) {
    error = _firstError(error);
    final text = error.toString();
    if (error is ProfileLoadException) return error;
    if (error is AuthException) {
      return ProfileLoadException(ProfileLoadProblem.signedOut, text);
    }
    if (error is PostgrestException) {
      final detail = '${error.code}: ${error.message}';
      return switch (error.code) {
        // JWT missing / expired.
        'PGRST301' ||
        'PGRST303' ||
        '28000' => ProfileLoadException(ProfileLoadProblem.signedOut, detail),
        // Missing table, column or function; blocked by a security rule.
        'PGRST205' ||
        '42P01' ||
        'PGRST202' ||
        '42883' ||
        'PGRST204' ||
        '42703' ||
        '42501' => ProfileLoadException(
          ProfileLoadProblem.databaseSetup,
          detail,
        ),
        _ => ProfileLoadException(ProfileLoadProblem.unknown, detail),
      };
    }
    // The HTTP client's errors differ by platform (ClientException,
    // SocketException, "Failed to fetch" on web), so match by text.
    if (RegExp(
      'ClientException|SocketException|Failed to fetch|XMLHttpRequest|'
      'TimeoutException|Connection (refused|reset|closed)|host lookup',
    ).hasMatch(text)) {
      return ProfileLoadException(ProfileLoadProblem.network, text);
    }
    return ProfileLoadException(ProfileLoadProblem.unknown, text);
  }

  // -------------------------------------------------------------------------
  // Clubs: follows and memberships (keyed by catalog id = groups.slug)
  // -------------------------------------------------------------------------

  final _groupIds = <String, String>{};

  Future<String> _groupId(String slug) async {
    final cached = _groupIds[slug];
    if (cached != null) return cached;
    final row = await client
        .from('groups')
        .select('id')
        .eq('slug', slug)
        .single();
    return _groupIds[slug] = row['id'] as String;
  }

  @override
  Future<void> setClubFollow(String clubId, {required bool following}) async {
    final groupId = await _groupId(clubId);
    if (following) {
      await client.from('group_follows').upsert({
        'profile_id': _uid,
        'group_id': groupId,
      }, ignoreDuplicates: true);
    } else {
      await client
          .from('group_follows')
          .delete()
          .eq('profile_id', _uid)
          .eq('group_id', groupId);
    }
  }

  @override
  Future<void> setClubNotifications(String clubId, DateTime? enabledAt) async {
    await client
        .from('group_follows')
        .update({
          'notifications_enabled_at': enabledAt?.toUtc().toIso8601String(),
        })
        .eq('profile_id', _uid)
        .eq('group_id', await _groupId(clubId));
  }

  @override
  Future<void> saveClubMembership(
    String clubId,
    ClubMembership? membership,
  ) async {
    final groupId = await _groupId(clubId);
    if (membership == null) {
      await client
          .from('group_memberships')
          .delete()
          .eq('profile_id', _uid)
          .eq('group_id', groupId);
    } else {
      await client.from('group_memberships').upsert({
        'profile_id': _uid,
        'group_id': groupId,
        'show_on_profile': membership.showOnProfile,
        'auto_rsvp_enabled_at': membership.autoRsvpEnabledAt
            ?.toUtc()
            .toIso8601String(),
      });
    }
  }

  @override
  Future<void> completeOnboarding(UserProfile profile) async {
    final saved = await client
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
        .eq('id', _uid)
        .select('id');
    if (saved.isEmpty) {
      // No row matched, so nothing was saved: don't pretend it worked.
      throw StateError('No profiles row to save onboarding to.');
    }
    // The database trigger adds the automatic follows (SSMU, faculty
    // association, First-Year Council). Clubs picked in onboarding:
    for (final MapEntry(key: clubId, value: membership)
        in profile.memberships.entries) {
      await saveClubMembership(clubId, membership);
    }
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
          ..._academicColumns(degree, year, profile.firstYearAtMcGill),
          'faculty': profile.faculty,
          'major': profile.major.isEmpty ? null : profile.major,
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

  @override
  Future<List<ClubEvent>> fetchEvents() async {
    final rows = await client
        .from('events')
        .select('*, groups(slug, name, avatar_url)')
        .order('created_at', ascending: false)
        .limit(500);
    return [for (final row in rows) _event(row)];
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
  Future<void> signOut() => client.auth.signOut();

  // -------------------------------------------------------------------------
  // Row → model
  // -------------------------------------------------------------------------

  AccountProfile _account(
    Map<String, dynamic> row, {
    Set<String> followed = const {},
    Map<String, DateTime> optIns = const {},
    Map<String, ClubMembership> memberships = const {},
  }) {
    final degree = degreeLevelFromDb(row['degree_level']);
    final faculty = row['faculty'] as String?;
    final done = row['onboarding_completed'] == true;
    return AccountProfile(
      id: row['id'] as String,
      handle: row['handle'] as String,
      fullName: row['full_name'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String? ?? '',
      academics: !done || degree == null || faculty == null
          ? null
          : UserProfile(
              degreeLevel: degree,
              year: uYearFromDb(row['u_year']),
              firstYearAtMcGill: row['is_first_year_u1'] == true,
              faculty: faculty,
              major: row['major'] as String?,
              interests: Set.unmodifiable(
                (row['interests'] as List? ?? const []).cast<String>(),
              ),
              followedClubIds: Set.unmodifiable(followed),
              clubNotificationOptIns: Map.unmodifiable(optIns),
              memberships: Map.unmodifiable(memberships),
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
      isFrosh: row['is_froshie_event'] == true,
      publishedAt: time('published_at'),
      createdAt: time('created_at'),
      startsAt: time('starts_at'),
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
          : '@${row['handle']}',
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
