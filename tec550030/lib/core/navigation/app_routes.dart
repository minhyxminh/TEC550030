import 'package:material_ui/material_ui.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/main_layout/main_layout.dart';

import '../../screens/auth/register_screen.dart';
import '../../screens/auth/session_gate.dart';
import '../../screens/auth/forgot_password_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String session = '/';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String mainLayout = '/main_layout';

  static Map<String, WidgetBuilder> get routes {
    return {
      session: (context) => const SessionGate(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
      mainLayout: (context) => const MainLayout(),
    };
  }
}
