import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/buddy_profile.dart';
import 'package:tec550030/models/gym_branch.dart';
import 'package:tec550030/screens/buddy/buddy_onboarding_screen.dart';
import 'package:tec550030/screens/buddy/buddy_swipe_screen.dart';
import 'package:tec550030/screens/home/home_screen.dart';
import 'package:tec550030/services/branch_service.dart';
import 'package:tec550030/services/buddy_service.dart';

import 'api_fixtures.dart';

class FakeBuddyService extends BuddyService {
  BuddyProfile? profile;
  Map<String, dynamic>? lastSavedPayload;

  FakeBuddyService({this.profile});

  @override
  Future<BuddyProfile?> getProfile() async => profile;

  @override
  Future<BuddyProfile> saveProfile(Map<String, dynamic> data) async {
    lastSavedPayload = data;
    profile = BuddyProfile.fromJson(data);
    return profile!;
  }
}

class FakeBranchService extends BranchService {
  const FakeBranchService();

  @override
  Future<List<GymBranch>> getBranches() async => const [
        GymBranch(
          id: '1',
          name: 'GymFlow Nguyễn Chí Thanh',
          address: 'Khu Nguyễn Chí Thanh',
          district: 'Quận 10',
          latitude: 10.7724,
          longitude: 106.6676,
          openingHours: '06:00-22:00',
        ),
      ];
}

Future<void> openScreen(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  ));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
    await ApiClient.saveSession({
      'access_token': 'valid-token',
      'refresh_token': 'valid-refresh',
    });
    ApiClient.httpClient = mockApi(fixtureResponse);
  });

  tearDown(() => ApiClient.httpClient.close());

  group('Home Entry Card', () {
    testWidgets('1. Home shows "Kết nối bạn tập" card', (tester) async {
      await openScreen(
        tester,
        HomeScreen(
          branchService: const FakeBranchService(),
          buddyService: FakeBuddyService(),
        ),
      );

      await scrollTo(tester, find.text('Kết nối bạn tập'));
      expect(find.text('Kết nối bạn tập'), findsOneWidget);
      expect(
        find.text('Tìm người cùng lịch và cùng mục tiêu tập luyện'),
        findsOneWidget,
      );
    });

    testWidgets('2. No profile / onboarding false: tap opens BuddyOnboardingScreen', (tester) async {
      final fakeBuddy = FakeBuddyService(profile: null);
      await openScreen(
        tester,
        HomeScreen(
          branchService: const FakeBranchService(),
          buddyService: fakeBuddy,
        ),
      );

      await scrollTo(tester, find.text('Kết nối bạn tập'));
      await tester.tap(find.text('Kết nối bạn tập'));
      await tester.pumpAndSettle();

      expect(find.byType(BuddyOnboardingScreen), findsOneWidget);
      expect(find.text('Thiết lập Gym Buddy'), findsOneWidget);
    });

    testWidgets('3. Completed profile: tap does NOT reopen onboarding, opens BuddySwipeScreen', (tester) async {
      final completedProfile = const BuddyProfile(
        userId: 'u1',
        name: 'Member Test',
        onboardingCompleted: true,
        fitnessGoal: 'MUSCLE_GAIN',
        experienceLevel: 'INTERMEDIATE',
        favoriteWorkouts: ['Chest'],
        preferredWorkoutTimes: ['EVENING'],
      );
      final fakeBuddy = FakeBuddyService(profile: completedProfile);

      await openScreen(
        tester,
        HomeScreen(
          branchService: const FakeBranchService(),
          buddyService: fakeBuddy,
        ),
      );

      await scrollTo(
        tester,
        find.text('Khám phá những người phù hợp để tập cùng'),
      );
      expect(find.text('Khám phá những người phù hợp để tập cùng'), findsOneWidget);

      await tester.tap(find.text('Kết nối bạn tập'));
      await tester.pumpAndSettle();

      expect(find.byType(BuddyOnboardingScreen), findsNothing);
      expect(find.byType(BuddySwipeScreen), findsOneWidget);
      expect(find.text('Kết nối bạn tập'), findsOneWidget);
    });
  });

  group('BuddyOnboardingScreen UI & Interactions', () {
    testWidgets('4. Goal single-selection works', (tester) async {
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: const FakeBranchService(),
          buddyService: FakeBuddyService(),
        ),
      );

      // Select 'Tăng cơ'
      await tester.tap(find.text('Tăng cơ'));
      await tester.pumpAndSettle();

      ChoiceChip chip = tester.widget(find.widgetWithText(ChoiceChip, 'Tăng cơ'));
      expect(chip.selected, isTrue);

      // Select 'Giảm mỡ' -> should switch
      await tester.tap(find.text('Giảm mỡ'));
      await tester.pumpAndSettle();

      chip = tester.widget(find.widgetWithText(ChoiceChip, 'Tăng cơ'));
      expect(chip.selected, isFalse);

      final chip2 = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Giảm mỡ'));
      expect(chip2.selected, isTrue);
    });

    testWidgets('5. Favorite workouts multi-selection works', (tester) async {
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: FakeBranchService(),
          buddyService: FakeBuddyService(),
        ),
      );

      await scrollTo(tester, find.text('Leg Day'));
      await tester.tap(find.text('Leg Day'));
      await scrollTo(tester, find.text('Chest'));
      await tester.tap(find.text('Chest'));
      await tester.pumpAndSettle();

      final chip1 = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Leg Day'));
      final chip2 = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Chest'));
      final chip3 = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Back'));

      expect(chip1.selected, isTrue);
      expect(chip2.selected, isTrue);
      expect(chip3.selected, isFalse);
    });

    testWidgets('6. Experience level selection works', (tester) async {
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: FakeBranchService(),
          buddyService: FakeBuddyService(),
        ),
      );

      await scrollTo(tester, find.text('Trung cấp'));
      await tester.tap(find.text('Trung cấp'));
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Trung cấp'));
      expect(chip.selected, isTrue);
    });

    testWidgets('7. Workout time multi-selection works', (tester) async {
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: FakeBranchService(),
          buddyService: FakeBuddyService(),
        ),
      );

      await scrollTo(tester, find.text('Sáng'));
      await tester.tap(find.text('Sáng'));
      await tester.tap(find.text('Tối'));
      await tester.pumpAndSettle();

      final chip1 = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Sáng'));
      final chip2 = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Tối'));
      final chip3 = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Trưa'));

      expect(chip1.selected, isTrue);
      expect(chip2.selected, isTrue);
      expect(chip3.selected, isFalse);
    });

    testWidgets('8. Looking-for-partner OFF: partner fields hidden', (tester) async {
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: FakeBranchService(),
          buddyService: FakeBuddyService(),
        ),
      );

      await scrollTo(
        tester,
        find.widgetWithText(SwitchListTile, 'Đang tìm bạn tập'),
      );
      expect(find.text('Chọn ngày muốn tập'), findsNothing);
      expect(find.text('Buổi tập cụ thể:'), findsNothing);
    });

    testWidgets('9. Looking-for-partner ON: partner fields visible', (tester) async {
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: FakeBranchService(),
          buddyService: FakeBuddyService(),
        ),
      );

      // Toggle switch
      final lookingSwitch =
          find.widgetWithText(SwitchListTile, 'Đang tìm bạn tập');
      await scrollTo(tester, lookingSwitch);
      await tester.tap(lookingSwitch);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Chọn ngày muốn tập'));
      expect(find.text('Chọn ngày muốn tập'), findsOneWidget);
      expect(find.text('Buổi tập cụ thể:'), findsOneWidget);
      expect(find.text('Chi nhánh tập:'), findsOneWidget);
    });

    testWidgets('10. Invalid partner time: save prevented', (tester) async {
      final fakeBuddy = FakeBuddyService();
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: const FakeBranchService(),
          buddyService: fakeBuddy,
        ),
      );

      // Simulate an existing profile with an invalid time range.
      final invalidTimeProfile = const BuddyProfile(
        userId: 'u1',
        name: 'Test',
        onboardingCompleted: true,
        fitnessGoal: 'MUSCLE_GAIN',
        experienceLevel: 'INTERMEDIATE',
        favoriteWorkouts: ['Leg Day'],
        preferredWorkoutTimes: ['AFTERNOON'],
        lookingForPartner: true,
        partnerDate: '2026-10-25',
        partnerStartTime: '19:00',
        partnerEndTime: '18:00',
        partnerWorkout: 'Leg Day',
        partnerGymId: '1',
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: BuddyOnboardingScreen(
          existingProfile: invalidTimeProfile,
          buddyService: fakeBuddy,
          branchService: const FakeBranchService(),
        ),
      ));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pump();

      // The profile is otherwise complete, so an invalid time range must block save.
      expect(fakeBuddy.lastSavedPayload, isNull);
    });

    testWidgets('10b. Looking-for-partner requires a date before save', (tester) async {
      final fakeBuddy = FakeBuddyService();
      final incompleteProfile = const BuddyProfile(
        userId: 'u1',
        name: 'Test',
        onboardingCompleted: true,
        fitnessGoal: 'MUSCLE_GAIN',
        experienceLevel: 'INTERMEDIATE',
        favoriteWorkouts: ['Leg Day'],
        preferredWorkoutTimes: ['EVENING'],
        lookingForPartner: true,
        partnerStartTime: '18:00',
        partnerEndTime: '19:00',
        partnerWorkout: 'Leg Day',
        partnerGymId: '1',
      );

      await openScreen(
        tester,
        BuddyOnboardingScreen(
          existingProfile: incompleteProfile,
          buddyService: fakeBuddy,
          branchService: const FakeBranchService(),
          homeGymId: '1',
        ),
      );

      await scrollTo(tester, find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pump();

      expect(find.text('Vui lòng chọn ngày muốn tập.'), findsWidgets);
      expect(fakeBuddy.lastSavedPayload, isNull);
    });

    testWidgets('11. Required fields missing: save prevented', (tester) async {
      final fakeBuddy = FakeBuddyService();
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: const FakeBranchService(),
          buddyService: fakeBuddy,
        ),
      );

      // Tap Hoàn tất without selecting anything
      await scrollTo(tester, find.text('Hoàn tất'));
      await tester.tap(find.text('Hoàn tất'));
      await tester.pump();

      expect(find.text('Vui lòng chọn mục tiêu tập luyện.'), findsWidgets);
      expect(fakeBuddy.lastSavedPayload, isNull);
    });

    testWidgets('12. Valid onboarding: BuddyService.saveProfile called with onboarding_completed=true', (tester) async {
      final fakeBuddy = FakeBuddyService();
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: const FakeBranchService(),
          buddyService: fakeBuddy,
        ),
      );

      await tester.tap(find.text('Tăng cơ'));
      await scrollTo(tester, find.text('Chest'));
      await tester.tap(find.text('Chest'));
      await scrollTo(tester, find.text('Mới bắt đầu'));
      await tester.tap(find.text('Mới bắt đầu'));
      await scrollTo(tester, find.text('Sáng'));
      await tester.tap(find.text('Sáng'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Hoàn tất'));
      await tester.tap(find.text('Hoàn tất'));
      await tester.pumpAndSettle();

      expect(fakeBuddy.lastSavedPayload, isNotNull);
      expect(fakeBuddy.lastSavedPayload!['onboarding_completed'], isTrue);
      expect(fakeBuddy.lastSavedPayload!['fitness_goal'], 'MUSCLE_GAIN');
      expect(fakeBuddy.lastSavedPayload!['favorite_workouts'], ['Chest']);
      expect(fakeBuddy.lastSavedPayload!['experience_level'], 'BEGINNER');
      expect(fakeBuddy.lastSavedPayload!['preferred_workout_times'], ['MORNING']);
      expect(fakeBuddy.lastSavedPayload!['enabled'], isTrue);
    });

    testWidgets('13. Edit mode: existing values are prefilled', (tester) async {
      final existing = const BuddyProfile(
        userId: 'u1',
        name: 'Edit Tester',
        onboardingCompleted: true,
        fitnessGoal: 'FAT_LOSS',
        experienceLevel: 'ADVANCED',
        favoriteWorkouts: ['Back', 'Cardio'],
        preferredWorkoutTimes: ['EVENING'],
        age: 28,
        gender: 'Nam',
        showAge: false,
        showGender: true,
        bio: 'Tập cùng nhau nâng cao sức khỏe',
        enabled: true,
      );

      await openScreen(
        tester,
        BuddyOnboardingScreen(
          existingProfile: existing,
          branchService: const FakeBranchService(),
          buddyService: FakeBuddyService(profile: existing),
        ),
      );

      expect(find.text('Chỉnh sửa sở thích'), findsOneWidget);

      final goalChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Giảm mỡ'),
      );
      expect(goalChip.selected, isTrue);

      final backChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Back'),
      );
      expect(backChip.selected, isTrue);

      await scrollTo(tester, find.text('Nâng cao'));
      final levelChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Nâng cao'),
      );
      expect(levelChip.selected, isTrue);

      await scrollTo(tester, find.text('Tập cùng nhau nâng cao sức khỏe'));
      expect(find.text('Tập cùng nhau nâng cao sức khỏe'), findsOneWidget);

      await scrollTo(tester, find.text('Lưu thay đổi'));
      expect(find.text('Lưu thay đổi'), findsOneWidget);
    });

    testWidgets('14. enabled toggle maps correctly', (tester) async {
      final fakeBuddy = FakeBuddyService();
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: const FakeBranchService(),
          buddyService: fakeBuddy,
        ),
      );

      await tester.tap(find.text('Tăng cơ'));
      await scrollTo(tester, find.text('Chest'));
      await tester.tap(find.text('Chest'));
      await scrollTo(tester, find.text('Mới bắt đầu'));
      await tester.tap(find.text('Mới bắt đầu'));
      await scrollTo(tester, find.text('Sáng'));
      await tester.tap(find.text('Sáng'));

      // Toggle enabled OFF
      final enabledToggle = find.widgetWithText(
        SwitchListTile,
        'Cho phép xuất hiện trong Kết nối bạn tập',
      );
      await scrollTo(tester, enabledToggle);
      await tester.tap(enabledToggle);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Hoàn tất'));
      await tester.tap(find.text('Hoàn tất'));
      await tester.pumpAndSettle();

      expect(fakeBuddy.lastSavedPayload!['enabled'], isFalse);
    });

    testWidgets('15. show_age/show_gender map correctly', (tester) async {
      final fakeBuddy = FakeBuddyService();
      await openScreen(
        tester,
        BuddyOnboardingScreen(
          branchService: const FakeBranchService(),
          buddyService: fakeBuddy,
        ),
      );

      await tester.tap(find.text('Tăng cơ'));
      await scrollTo(tester, find.text('Chest'));
      await tester.tap(find.text('Chest'));
      await scrollTo(tester, find.text('Mới bắt đầu'));
      await tester.tap(find.text('Mới bắt đầu'));
      await scrollTo(tester, find.text('Sáng'));
      await tester.tap(find.text('Sáng'));

      // Toggle show_age OFF
      final showAgeToggle = find.widgetWithText(
        SwitchListTile,
        'Hiển thị tuổi trên Buddy Card',
      );
      await scrollTo(tester, showAgeToggle);
      await tester.tap(showAgeToggle);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Hoàn tất'));
      await tester.tap(find.text('Hoàn tất'));
      await tester.pumpAndSettle();

      expect(fakeBuddy.lastSavedPayload!['show_age'], isFalse);
      expect(fakeBuddy.lastSavedPayload!['show_gender'], isTrue);
    });
  });
}
