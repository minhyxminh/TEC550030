import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_routes.dart';
import 'core/api/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Mascot and boss-battle clips are frame sequences: keep a whole clip
  // decoded so playback never waits on a frame.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    ApiClient.sessionExpired.addListener(_onSessionExpired);
  }

  void _onSessionExpired() {
    if (!ApiClient.sessionExpired.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ApiClient.sessionExpired.value) return;
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
      ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.'),
        ),
      );
    });
  }

  @override
  void dispose() {
    ApiClient.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymFlow',
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      initialRoute: AppRoutes.session,
      routes: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
