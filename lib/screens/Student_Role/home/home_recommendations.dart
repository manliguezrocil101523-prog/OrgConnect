import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/app_state.dart';

/// Calculates organization recommendations using the current student's data.
class OrgRecommender {
  OrgRecommender._();

  static String? _currentUserId() {
    return supabase.Supabase.instance.client.auth.currentUser?.id;
  }

  static void _addIfValid(Set<String> destination, String? id) {
    if (id != null && id.trim().isNotEmpty) {
      destination.add(id);
    }
  }

  /// Returns organizations the student has joined through any supported
  /// membership source.
  static Set<String> joinedOrgIds() {
    final state = AppState.instance;
    final currentStudent = state.currentStudent;
    final userId = _currentUserId();

    final joinedIds = <String>{};

    if (currentStudent != null) {
      for (final id in currentStudent.joinedOrgIds) {
        _addIfValid(joinedIds, id);
      }
    }

    if (userId != null && userId.isNotEmpty) {
      for (final application in state.applications) {
        if (application.userId != userId) {
          continue;
        }

        final isApproved = application.status == ApplicationStatus.approved ||
            application.status == ApplicationStatus.accepted;

        if (isApproved) {
          _addIfValid(joinedIds, application.orgId);
        }
      }
    }

    if (currentStudent != null && currentStudent.id.trim().isNotEmpty) {
      for (final member in state.members) {
        if (member.profileId == currentStudent.id) {
          _addIfValid(joinedIds, member.orgId);
        }
      }
    }

    return joinedIds;
  }

  /// Returns organizations for which the authenticated student has applied.
  static Set<String> appliedOrgIds() {
    final userId = _currentUserId();

    if (userId == null || userId.isEmpty) {
      return <String>{};
    }

    final appliedIds = <String>{};

    for (final application in AppState.instance.applications) {
      if (application.userId == userId) {
        _addIfValid(appliedIds, application.orgId);
      }
    }

    return appliedIds;
  }

  static String _normalizedCategory(String value) {
    return value.trim().toLowerCase();
  }

  static int _memberCount(
    Map<String, int> memberCounts,
    String orgId,
  ) {
    final count = memberCounts[orgId] ?? 0;
    return count > 0 ? count : 0;
  }

  /// Ranks organizations by joined-category relevance, application status,
  /// member count, and name. The result is deterministic for the same input.
  static List<Organization> recommend({
    Map<String, int> memberCounts = const <String, int>{},
    int limit = 10,
  }) {
    if (limit <= 0) {
      return <Organization>[];
    }

    final state = AppState.instance;
    final joinedIds = joinedOrgIds();
    final appliedIds = appliedOrgIds();

    final joinedCategories = <String>{};

    for (final organization in state.organizations) {
      if (joinedIds.contains(organization.id)) {
        final category = _normalizedCategory(organization.category);

        if (category.isNotEmpty) {
          joinedCategories.add(category);
        }
      }
    }

    final candidates = state.organizations.where((organization) {
      return organization.id.trim().isNotEmpty &&
          !joinedIds.contains(organization.id);
    }).toList();

    int score(Organization organization) {
      var result = 0;
      final category = _normalizedCategory(organization.category);

      if (category.isNotEmpty && joinedCategories.contains(category)) {
        result += 3;
      }

      if (appliedIds.contains(organization.id)) {
        result -= 5;
      }

      return result;
    }

    candidates.sort((a, b) {
      final scoreComparison = score(b).compareTo(score(a));

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      final memberComparison = _memberCount(
        memberCounts,
        b.id,
      ).compareTo(
        _memberCount(memberCounts, a.id),
      );

      if (memberComparison != 0) {
        return memberComparison;
      }

      final nameComparison = a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          );

      if (nameComparison != 0) {
        return nameComparison;
      }

      return a.id.compareTo(b.id);
    });

    return candidates.take(limit).toList();
  }
}
