import 'package:material_ui/material_ui.dart';

// "Hổ Flow" palette: cam hổ, mực, tím, bạc hà on a soft lavender-white base.
class AppColors {
  // Cam hổ — the brand accent.
  static const Color primaryOrange = Color(0xFFFF7A3D);
  static const Color strongOrange = Color(0xFFF2652A);
  static const Color deepOrange = Color(0xFFC94A14);
  static const Color sunOrange = Color(0xFFFF9A63);
  static const Color peach = Color(0xFFFFE6D9);
  static const Color gymPointYellow = Color(0xFFFFB547);
  static const Color butter = Color(0xFFFFF1D1);

  // Mực — text, dark surfaces and primary actions.
  static const Color ink = Color(0xFF1E1B2E);
  static const Color inkSoft = Color(0xFF2C2840);

  // Tím — secondary accent (chat, info tiles, highlights).
  static const Color purple = Color(0xFF8B6CFF);
  static const Color lavender = Color(0xFFEEEAFB);

  // Bạc hà — positive states.
  static const Color mint = Color(0xFFDDF5E6);

  // Neutrals.
  static const Color warmBackground = Color(0xFFF7F5FB);
  static const Color field = Color(0xFFF3F1F9);
  static const Color sand = Color(0xFFE6E2F0);
  static const Color darkText = ink;
  static const Color secondaryText = Color(0xFF6E6A80);
  static const Color white = Colors.white;

  // Status colours.
  static const Color success = Color(0xFF1E9E5E);
  static const Color successSoft = mint;
  static const Color info = Color(0xFF3B7BF0);
  static const Color infoSoft = Color(0xFFE4EDFD);
  static const Color warning = Color(0xFFF08A24);
  static const Color error = Color(0xFFD9363E);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A52), primaryOrange],
  );
}
