import 'package:material_ui/material_ui.dart';

import '../../core/navigation/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  String? _error;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() => _error = null);
    try {
      final auth = AuthService();
      final loggedIn = await auth.isLoggedIn();
      if (loggedIn) await auth.getCurrentUser();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        loggedIn ? AppRoutes.mainLayout : AppRoutes.login,
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _error == null
        ? const LoadingView()
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorState(message: _error!, onRetry: _restore),
              TextButton(
                onPressed: () async {
                  await AuthService().logout();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                },
                child: const Text('Về đăng nhập'),
              ),
            ],
          ),
  );
}
