import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/buddy_match.dart';
import 'package:tec550030/models/buddy_profile.dart';
import 'package:tec550030/screens/buddy/buddy_group_create_screen.dart';
import 'package:tec550030/services/buddy_service.dart';

class FakeGroupBuddyService extends BuddyService {
  final List<BuddyMatch> matches;
  final Object? loadError;
  final bool failCreate;

  String? createdTitle;
  List<String>? createdMemberIds;

  FakeGroupBuddyService({
    this.matches = const [],
    this.loadError,
    this.failCreate = true,
  });

  @override
  Future<List<BuddyMatch>> getMatches() async {
    if (loadError != null) throw loadError!;
    return matches;
  }

  @override
  Future<Map<String, dynamic>> createGroup(
    String title,
    List<String> memberIds,
  ) async {
    createdTitle = title;
    createdMemberIds = List<String>.from(memberIds);
    if (failCreate) throw Exception('create failed');
    return {
      'conversation_id': 'group-conv',
      'type': 'GROUP',
      'title': title,
      'member_count': memberIds.length + 1,
    };
  }
}

const me = BuddyProfile(
  userId: 'me',
  name: 'Me',
  onboardingCompleted: true,
);

BuddyMatch match(String id, String userId, String name) => BuddyMatch(
      id: id,
      otherUserId: userId,
      otherUserName: name,
      conversationId: 'direct-$id',
    );

Future<void> pumpGroup(
  WidgetTester tester,
  FakeGroupBuddyService service,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BuddyGroupCreateScreen(
        profile: me,
        buddyService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('requires at least two existing matches', (tester) async {
    await pumpGroup(
      tester,
      FakeGroupBuddyService(
        matches: [match('m1', 'u1', 'Lan')],
      ),
    );

    expect(find.text('Cần ít nhất 2 Gym Buddy đã match'), findsOneWidget);
  });

  testWidgets('shows matched buddies and selection count', (tester) async {
    await pumpGroup(
      tester,
      FakeGroupBuddyService(
        matches: [
          match('m1', 'u1', 'Lan'),
          match('m2', 'u2', 'Mai'),
        ],
      ),
    );

    expect(find.text('Lan'), findsOneWidget);
    expect(find.text('Mai'), findsOneWidget);
    expect(find.text('0 đã chọn'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Lan'));
    await tester.pump();

    expect(find.text('1 đã chọn'), findsOneWidget);
  });

  testWidgets('validation blocks group creation with fewer than two selections',
      (tester) async {
    final service = FakeGroupBuddyService(
      matches: [
        match('m1', 'u1', 'Lan'),
        match('m2', 'u2', 'Mai'),
      ],
    );
    await pumpGroup(tester, service);

    await tester.enterText(find.byType(TextField), 'Leg Day Team');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Lan'));
    await tester.tap(find.text('Tạo nhóm và mở chat'));
    await tester.pump();

    expect(find.text('Chọn ít nhất 2 Gym Buddy để tạo nhóm.'), findsWidgets);
    expect(service.createdTitle, isNull);
  });

  testWidgets('two selected matched buddies are sent to createGroup',
      (tester) async {
    final service = FakeGroupBuddyService(
      matches: [
        match('m1', 'u1', 'Lan'),
        match('m2', 'u2', 'Mai'),
      ],
    );
    await pumpGroup(tester, service);

    await tester.enterText(find.byType(TextField), 'Leg Day Team');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Lan'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Mai'));
    await tester.pump();

    await tester.tap(find.text('Tạo nhóm và mở chat'));
    await tester.pumpAndSettle();

    expect(service.createdTitle, 'Leg Day Team');
    expect(service.createdMemberIds, containsAll(['u1', 'u2']));
    expect(find.textContaining('Không thể tạo nhóm:'), findsWidgets);
  });

  testWidgets('load failure shows retry state', (tester) async {
    await pumpGroup(
      tester,
      FakeGroupBuddyService(loadError: Exception('offline')),
    );

    expect(find.text('Không thể tải danh sách Gym Buddy'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
