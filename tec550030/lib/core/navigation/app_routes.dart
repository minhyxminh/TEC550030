import 'package:flutter/material.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/main_layout/main_layout.dart';

import '../../screens/auth/register_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String mainLayout = '/main_layout';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      mainLayout: (context) => const MainLayout(),
    };
  }
}
