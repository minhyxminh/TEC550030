import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tec550030/core/api/api_client.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/gym_branch.dart';
import 'package:tec550030/screens/home/branch_selection_screen.dart';
import 'package:tec550030/services/location_service.dart';

import 'api_fixtures.dart';

Future<void> openScreen(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: child));
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

  test('branch model maps catalogue coordinates and hours', () {
    final branch = GymBranch.fromJson(gymBranches.last);
    expect(branch.id, 'q5');
    expect(branch.latitude, 10.7481);
    expect(branch.openingHours, '06:00-22:00');
  });

  testWidgets('denied GPS still lists selectable branches without distances', (
    tester,
  ) async {
    String? selectedGym;
    ApiClient.httpClient = mockApi((request) {
      if (request.url.path == '/me/home-gym') {
        selectedGym = jsonDecode(request.body)['gym_id'] as String;
        return jsonResponse({...profile, 'home_gym_id': selectedGym});
      }
      return fixtureResponse(request);
    });
    await openScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => BranchSelectionScreen(
                  locationService: LocationService(
                    locationProvider: () async =>
                        const LocationResult(denied: true),
                  ),
                ),
              ),
            ),
            child: const Text('Open branch picker'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open branch picker'));
    await tester.pumpAndSettle();
    expect(find.text('GymFlow Nguyễn Chí Thanh'), findsOneWidget);
    expect(find.text('GymFlow Hậu Giang'), findsOneWidget);
    expect(find.text('Không có quyền vị trí. Bạn vẫn có thể chọn cơ sở.'), findsOneWidget);
    expect(find.textContaining(' km'), findsNothing);
    await tester.tap(find.text('GymFlow Hậu Giang'));
    await tester.pumpAndSettle();
    expect(selectedGym, 'q5');
    expect(find.text('Open branch picker'), findsOneWidget);
  });

  testWidgets('available GPS sorts branches by calculated distance', (
    tester,
  ) async {
    await openScreen(
      tester,
      const BranchSelectionScreen(
        locationService: LocationService(
          locationProvider: _nearHauGiang,
        ),
      ),
    );
    final near = tester.getTopLeft(find.text('GymFlow Hậu Giang')).dy;
    final far = tester.getTopLeft(find.text('GymFlow Nguyễn Chí Thanh')).dy;
    expect(near, lessThan(far));
    expect(find.text('0.0 km'), findsOneWidget);
    expect(find.text('Không có quyền vị trí. Bạn vẫn có thể chọn cơ sở.'), findsNothing);
  });
}

Future<LocationResult> _nearHauGiang() async =>
    const LocationResult(latitude: 10.7481, longitude: 106.6358);
