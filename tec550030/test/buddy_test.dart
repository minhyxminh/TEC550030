import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/models/buddy_match.dart';
import 'package:tec550030/models/buddy_profile.dart';
import 'package:tec550030/services/buddy_service.dart';

import 'api_fixtures.dart';

void main() {
  group('BuddyProfile Model', () {
    test('parses full json with all optional fields and lists', () {
      final json = {
        'user_id': 'u100',
        'name': 'Trần Văn Gym',
        'avatar_url': 'https://example.com/avatar.jpg',
        'avatar_path': 'avatars/u100.jpg',
        'age': 25,
        'gender': 'Nam',
        'show_age': true,
        'show_gender': false,
        'home_gym_id': '1',
        'gym_name': 'GymFlow Nguyễn Chí Thanh',
        'district': 'Quận 10',
        'enabled': true,
        'fitness_goal': 'Tăng cơ',
        'experience_level': 'INTERMEDIATE',
        'favorite_workouts': ['Ngực', 'Tay sau'],
        'preferred_workout_times': ['Chiều tối'],
        'workout_style': ['Tập trung cao'],
        'bio': 'Tìm bạn tập buổi chiều 18h',
        'onboarding_completed': true,
        'looking_for_partner': true,
        'partner_date': '2026-10-25',
        'partner_start_time': '18:00',
        'partner_end_time': '19:30',
        'partner_workout': 'Ngực + Tay sau',
        'partner_gym_id': '1',
        'partner_gym_name': 'GymFlow Nguyễn Chí Thanh',
        'partner_note': 'Cùng đẩy tạ nhé!',
      };

      final profile = BuddyProfile.fromJson(json);

      expect(profile.userId, 'u100');
      expect(profile.name, 'Trần Văn Gym');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.age, 25);
      expect(profile.gender, 'Nam');
      expect(profile.showAge, true);
      expect(profile.showGender, false);
      expect(profile.homeGymId, '1');
      expect(profile.gymName, 'GymFlow Nguyễn Chí Thanh');
      expect(profile.district, 'Quận 10');
      expect(profile.enabled, true);
      expect(profile.fitnessGoal, 'Tăng cơ');
      expect(profile.experienceLevel, 'INTERMEDIATE');
      expect(profile.favoriteWorkouts, ['Ngực', 'Tay sau']);
      expect(profile.preferredWorkoutTimes, ['Chiều tối']);
      expect(profile.workoutStyle, ['Tập trung cao']);
      expect(profile.bio, 'Tìm bạn tập buổi chiều 18h');
      expect(profile.onboardingCompleted, true);
      expect(profile.lookingForPartner, true);
      expect(profile.partnerDate, '2026-10-25');
      expect(profile.partnerStartTime, '18:00');
      expect(profile.partnerEndTime, '19:30');
      expect(profile.partnerWorkout, 'Ngực + Tay sau');
      expect(profile.partnerGymId, '1');
      expect(profile.partnerGymName, 'GymFlow Nguyễn Chí Thanh');
      expect(profile.partnerNote, 'Cùng đẩy tạ nhé!');
    });

    test('handles null and missing fields gracefully', () {
      final json = <String, dynamic>{
        'user_id': 'u200',
        'name': 'Nguyễn Thị B',
      };

      final profile = BuddyProfile.fromJson(json);

      expect(profile.userId, 'u200');
      expect(profile.name, 'Nguyễn Thị B');
      expect(profile.avatarUrl, isNull);
      expect(profile.age, isNull);
      expect(profile.gender, isNull);
      expect(profile.showAge, true);
      expect(profile.showGender, true);
      expect(profile.enabled, true);
      expect(profile.favoriteWorkouts, isEmpty);
      expect(profile.preferredWorkoutTimes, isEmpty);
      expect(profile.workoutStyle, isEmpty);
      expect(profile.onboardingCompleted, false);
      expect(profile.lookingForPartner, false);
    });

    test('toJson serializes correctly', () {
      const profile = BuddyProfile(
        userId: 'u300',
        name: 'Lê Văn C',
        fitnessGoal: 'Giảm cân',
        favoriteWorkouts: ['Cardio'],
      );

      final map = profile.toJson();
      expect(map['user_id'], 'u300');
      expect(map['name'], 'Lê Văn C');
      expect(map['fitness_goal'], 'Giảm cân');
      expect(map['favorite_workouts'], ['Cardio']);
    });
  });

  group('BuddyMatch Model', () {
    test('parses full json', () {
      final json = {
        'id': 'm100',
        'other_user_id': 'u200',
        'other_user_name': 'Nguyễn Thị B',
        'other_avatar_url': 'https://example.com/b.jpg',
        'other_avatar_path': 'avatars/b.jpg',
        'conversation_id': 'c100',
        'created_at': '2026-10-20T10:00:00.000Z',
      };

      final match = BuddyMatch.fromJson(json);

      expect(match.id, 'm100');
      expect(match.otherUserId, 'u200');
      expect(match.otherUserName, 'Nguyễn Thị B');
      expect(match.otherAvatarUrl, 'https://example.com/b.jpg');
      expect(match.conversationId, 'c100');
      expect(match.createdAt, isNotNull);
    });

    test('toJson produces expected map', () {
      final match = BuddyMatch(
        id: 'm101',
        otherUserId: 'u201',
        otherUserName: 'Hoàng D',
        conversationId: 'c101',
        createdAt: DateTime.parse('2026-10-20T12:00:00Z'),
      );

      final map = match.toJson();
      expect(map['id'], 'm101');
      expect(map['other_user_id'], 'u201');
      expect(map['other_user_name'], 'Hoàng D');
      expect(map['conversation_id'], 'c101');
    });
  });

  group('BuddyService', () {
    const service = BuddyService();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.clearToken();
      await ApiClient.saveSession({
        'access_token': 'valid-token',
        'refresh_token': 'valid-refresh',
      });
    });

    tearDown(() => ApiClient.httpClient.close());

    test('getProfile returns BuddyProfile from /buddy/profile', () async {
      ApiClient.httpClient = mockApi((request) {
        if (request.url.path == '/buddy/profile') {
          return jsonResponse({
            'user_id': 'u1',
            'name': 'User One',
            'age': 22,
            'fitness_goal': 'Tăng cơ',
            'onboarding_completed': true,
          });
        }
        return http.Response('Not found', 404);
      });

      final profile = await service.getProfile();
      expect(profile, isNotNull);
      expect(profile!.userId, 'u1');
      expect(profile.name, 'User One');
      expect(profile.age, 22);
      expect(profile.onboardingCompleted, true);
    });

    test('saveProfile posts data to /buddy/profile and parses response', () async {
      Map<String, dynamic>? postedBody;
      ApiClient.httpClient = mockApi((request) {
        if (request.url.path == '/buddy/profile' && request.method == 'POST') {
          postedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({
            ...postedBody!,
            'user_id': 'u1',
            'name': 'User One',
          });
        }
        return http.Response('Not found', 404);
      });

      final saved = await service.saveProfile({
        'age': 26,
        'fitness_goal': 'Giảm mỡ',
        'onboarding_completed': true,
      });

      expect(postedBody?['age'], 26);
      expect(postedBody?['fitness_goal'], 'Giảm mỡ');
      expect(saved.age, 26);
      expect(saved.fitnessGoal, 'Giảm mỡ');
    });

    test('getFeed fetches candidates from /buddy/feed', () async {
      ApiClient.httpClient = mockApi((request) {
        if (request.url.path == '/buddy/feed') {
          expect(request.url.queryParameters['limit'], '10');
          return jsonResponse({
            'candidates': [
              {'user_id': 'c1', 'name': 'Candidate 1', 'age': 24},
              {'user_id': 'c2', 'name': 'Candidate 2', 'age': 28},
            ],
          });
        }
        return http.Response('Not found', 404);
      });

      final candidates = await service.getFeed(limit: 10);
      expect(candidates.length, 2);
      expect(candidates[0].userId, 'c1');
      expect(candidates[1].userId, 'c2');
    });

    test('swipe sends action to /buddy/swipe and returns match result', () async {
      ApiClient.httpClient = mockApi((request) {
        if (request.url.path == '/buddy/swipe' && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['target_id'], 'target-uuid');
          expect(body['action'], 'LIKE');
          return jsonResponse({
            'matched': true,
            'action': 'LIKE',
            'match_id': 'match-uuid',
            'conversation_id': 'conv-uuid',
          });
        }
        return http.Response('Not found', 404);
      });

      final result = await service.swipe('target-uuid', 'LIKE');
      expect(result['matched'], true);
      expect(result['action'], 'LIKE');
      expect(result['conversation_id'], 'conv-uuid');
    });

    test('getMatches parses list from /buddy/matches', () async {
      ApiClient.httpClient = mockApi((request) {
        if (request.url.path == '/buddy/matches') {
          return jsonResponse({
            'matches': [
              {
                'id': 'm1',
                'other_user_id': 'u2',
                'other_user_name': 'Friend',
                'conversation_id': 'conv1',
              },
            ],
          });
        }
        return http.Response('Not found', 404);
      });

      final matches = await service.getMatches();
      expect(matches.length, 1);
      expect(matches.first.id, 'm1');
      expect(matches.first.otherUserName, 'Friend');
      expect(matches.first.conversationId, 'conv1');
    });
  });
}
