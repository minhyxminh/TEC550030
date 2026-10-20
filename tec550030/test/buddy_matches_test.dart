import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/buddy_match.dart';
import 'package:tec550030/models/buddy_profile.dart';
import 'package:tec550030/screens/buddy/buddy_matches_screen.dart';
import 'package:tec550030/services/buddy_service.dart';

class FakeMatchesBuddyService extends BuddyService {
  final List<BuddyMatch> matches;
  final Object? error;

  FakeMatchesBuddyService({
    this.matches = const [],
    this.error,
  });

  @override
  Future<List<BuddyMatch>> getMatches() async {
    if (error != null) throw error!;
    return List<BuddyMatch>.from(matches);
  }
}

const me = BuddyProfile(
  userId: 'me',
  name: 'Me',
  onboardingCompleted: true,
);

Future<void> pumpMatches(
  WidgetTester tester,
  FakeMatchesBuddyService service,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BuddyMatchesScreen(
        profile: me,
        buddyService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state explains where future matches appear', (tester) async {
    await pumpMatches(tester, FakeMatchesBuddyService());

    expect(find.text('Bạn tập đã kết nối'), findsOneWidget);
    expect(find.text('Chưa có Gym Buddy đã kết nối'), findsOneWidget);
    expect(find.byTooltip('Tạo nhóm bạn tập'), findsOneWidget);
  });

  testWidgets('matched buddy is visible with persistent chat action',
      (tester) async {
    await pumpMatches(
      tester,
      FakeMatchesBuddyService(
        matches: const [
          BuddyMatch(
            id: 'm1',
            otherUserId: 'u2',
            otherUserName: 'Linh',
            conversationId: 'conv-1',
          ),
        ],
      ),
    );

    expect(find.text('Linh'), findsOneWidget);
    expect(find.text('Gym Buddy · Đã kết nối'), findsOneWidget);
    expect(find.byTooltip('Nhắn tin'), findsOneWidget);
  });

  testWidgets('load failure shows retry state', (tester) async {
    await pumpMatches(
      tester,
      FakeMatchesBuddyService(error: Exception('offline')),
    );

    expect(find.text('Không thể tải Gym Buddy'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
