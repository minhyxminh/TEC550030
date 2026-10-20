import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/buddy_profile.dart';
import 'package:tec550030/screens/buddy/buddy_swipe_screen.dart';
import 'package:tec550030/services/buddy_service.dart';

class FakeSwipeBuddyService extends BuddyService {
  final List<BuddyProfile> feed;
  final Object? feedError;
  final Map<String, Map<String, dynamic>> swipeResults;
  final List<String> actions = [];

  FakeSwipeBuddyService({
    this.feed = const [],
    this.feedError,
    this.swipeResults = const {},
  });

  @override
  Future<List<BuddyProfile>> getFeed({int limit = 20}) async {
    if (feedError != null) throw feedError!;
    return List<BuddyProfile>.from(feed);
  }

  @override
  Future<Map<String, dynamic>> swipe(String targetId, String action) async {
    actions.add('$action:$targetId');
    return swipeResults['$action:$targetId'] ??
        <String, dynamic>{'matched': false, 'action': action};
  }

  @override
  Future<BuddyProfile?> getProfile() async => null;
}

Future<void> pumpSwipe(
  WidgetTester tester, {
  required FakeSwipeBuddyService service,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  const me = BuddyProfile(
    userId: 'me',
    name: 'Me',
    onboardingCompleted: true,
    homeGymId: '1',
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BuddySwipeScreen(
        profile: me,
        buddyService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BuddyProfile candidate({
  String id = 'u2',
  String name = 'Lan',
  bool looking = true,
  String gymId = '1',
  String gymName = 'GymFlow Nguyễn Chí Thanh',
  String district = 'Quận 10',
  String goal = 'MUSCLE_GAIN',
  List<String> workouts = const ['Leg Day', 'Glutes'],
  List<String> times = const ['EVENING'],
}) {
  return BuddyProfile(
    userId: id,
    name: name,
    avatarUrl: '',
    age: 24,
    gender: 'Nữ',
    showAge: true,
    showGender: true,
    homeGymId: gymId,
    gymName: gymName,
    district: district,
    onboardingCompleted: true,
    fitnessGoal: goal,
    experienceLevel: 'INTERMEDIATE',
    favoriteWorkouts: workouts,
    preferredWorkoutTimes: times,
    workoutStyle: const ['Tập nghiêm túc', 'Thích có spotter'],
    bio: 'Tìm bạn tập buổi tối.',
    lookingForPartner: looking,
    partnerDate: looking ? '2026-10-25' : null,
    partnerStartTime: looking ? '18:00' : null,
    partnerEndTime: looking ? '19:30' : null,
    partnerWorkout: looking ? 'Leg Day' : null,
    partnerGymName: looking ? 'GymFlow Nguyễn Chí Thanh' : null,
    partnerNote: looking ? 'Cùng tập chân nhé' : null,
  );
}

void main() {
  testWidgets('shows loading then first candidate front card', (tester) async {
    final service = FakeSwipeBuddyService(feed: [candidate()]);
    await pumpSwipe(tester, service: service);

    expect(find.text('Lan'), findsOneWidget);
    expect(find.text('Đang tìm bạn tập'), findsOneWidget);
    expect(find.text('GymFlow Nguyễn Chí Thanh · Quận 10'), findsOneWidget);
  });

  testWidgets('tap flips card and tap again returns to front', (tester) async {
    final service = FakeSwipeBuddyService(feed: [candidate()]);
    await pumpSwipe(tester, service: service);

    await tester.tap(find.text('Lan'));
    await tester.pumpAndSettle();

    expect(find.text('Mục tiêu'), findsOneWidget);
    expect(find.text('Tăng cơ'), findsOneWidget);
    expect(find.text('Phong cách'), findsOneWidget);

    await tester.tap(find.text('Lan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Chạm để xem mục tiêu, lịch tập và phong cách tập'),
      findsOneWidget,
    );
  });

  testWidgets('pass button sends PASS and advances candidate', (tester) async {
    final service = FakeSwipeBuddyService(
      feed: [
        candidate(id: 'u2', name: 'Lan'),
        candidate(id: 'u3', name: 'Mai', looking: false),
      ],
    );
    await pumpSwipe(tester, service: service);

    await tester.tap(find.byTooltip('Bỏ qua'));
    await tester.pumpAndSettle();

    expect(service.actions, ['PASS:u2']);
    expect(find.text('Mai'), findsOneWidget);
    expect(find.text('Lan'), findsNothing);
  });

  testWidgets('connect button sends LIKE and advances candidate', (tester) async {
    final service = FakeSwipeBuddyService(
      feed: [
        candidate(id: 'u2', name: 'Lan'),
        candidate(id: 'u3', name: 'Mai'),
      ],
    );
    await pumpSwipe(tester, service: service);

    await tester.tap(find.byTooltip('Kết nối'));
    await tester.pumpAndSettle();

    expect(service.actions, ['LIKE:u2']);
    expect(find.text('Mai'), findsOneWidget);
  });

  testWidgets('drag left passes current candidate', (tester) async {
    final service = FakeSwipeBuddyService(
      feed: [
        candidate(id: 'u2', name: 'Lan'),
        candidate(id: 'u3', name: 'Mai'),
      ],
    );
    await pumpSwipe(tester, service: service);

    final cardFinder = find.text('Lan');
    final center = tester.getCenter(cardFinder);
    await tester.dragFrom(center, const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(service.actions, ['PASS:u2']);
    expect(find.text('Mai'), findsOneWidget);
  });

  testWidgets('drag right likes current candidate', (tester) async {
    final service = FakeSwipeBuddyService(
      feed: [
        candidate(id: 'u2', name: 'Lan'),
        candidate(id: 'u3', name: 'Mai'),
      ],
    );
    await pumpSwipe(tester, service: service);

    final center = tester.getCenter(find.text('Lan'));
    await tester.dragFrom(center, const Offset(180, 0));
    await tester.pumpAndSettle();

    expect(service.actions, ['LIKE:u2']);
    expect(find.text('Mai'), findsOneWidget);
  });


  testWidgets('mutual like shows Gym Match dialog with chat action', (tester) async {
    final service = FakeSwipeBuddyService(
      feed: [candidate()],
      swipeResults: const {
        'LIKE:u2': {
          'matched': true,
          'action': 'LIKE',
          'match_id': 'match-1',
          'conversation_id': 'conv-1',
          'is_new': true,
        },
      },
    );
    await pumpSwipe(tester, service: service);

    await tester.tap(find.byTooltip('Kết nối'));
    await tester.pumpAndSettle();

    expect(find.text('Gym Match!'), findsOneWidget);
    expect(find.text('Bạn và Lan cùng muốn kết nối.'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsOneWidget);
    expect(find.text('Tiếp tục xem'), findsOneWidget);
  });

  testWidgets('filters can narrow candidates by goal', (tester) async {
    final service = FakeSwipeBuddyService(
      feed: [
        candidate(id: 'u2', name: 'Lan', goal: 'MUSCLE_GAIN'),
        candidate(
          id: 'u3',
          name: 'Mai',
          goal: 'FAT_LOSS',
          gymId: '2',
          gymName: 'GymFlow Hậu Giang',
          district: 'Quận 6',
          workouts: const ['Cardio'],
          times: const ['MORNING'],
        ),
      ],
    );
    await pumpSwipe(tester, service: service);

    await tester.tap(find.byTooltip('Bộ lọc'));
    await tester.pumpAndSettle();

    expect(find.text('Bộ lọc bạn tập'), findsOneWidget);
    await tester.tap(find.text('Giảm mỡ'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();

    expect(find.text('Mai'), findsOneWidget);
    expect(find.text('Lan'), findsNothing);
    expect(find.textContaining('Đang lọc'), findsOneWidget);
  });

  testWidgets('empty state is shown when there are no candidates', (tester) async {
    await pumpSwipe(
      tester,
      service: FakeSwipeBuddyService(feed: const []),
    );

    expect(find.text('Hết hồ sơ phù hợp lúc này'), findsOneWidget);
    expect(find.text('Tải lại'), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    await pumpSwipe(
      tester,
      service: FakeSwipeBuddyService(feedError: Exception('offline')),
    );

    expect(find.text('Không thể tải danh sách bạn tập'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
