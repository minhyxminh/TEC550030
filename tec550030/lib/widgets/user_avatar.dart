import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;

  /// Shown as an initial when there is no photo.
  final String? name;

  /// Rounded square instead of a circle.
  final bool square;
  const UserAvatar({
    super.key,
    this.url,
    this.radius = 38,
    this.name,
    this.square = false,
  });
  @override
  Widget build(BuildContext context) {
    final initial = name?.trim().characters.firstOrNull?.toUpperCase();
    final fallback = Container(
      color: AppColors.primaryOrange,
      alignment: Alignment.center,
      child: initial == null
          ? Icon(Icons.person_outline, size: radius * 1.1, color: Colors.white)
          : Text(
              initial,
              style: AppTextStyles.display.copyWith(
                color: AppColors.ink,
                fontSize: radius * 0.95,
              ),
            ),
    );
    final uri = Uri.tryParse(url ?? '');
    final image = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: uri?.scheme == 'https' && uri!.host.isNotEmpty
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            )
          : fallback,
    );
    return Semantics(
      label: 'Ảnh đại diện',
      image: true,
      child: square
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius * 0.55),
              child: image,
            )
          : ClipOval(child: image),
    );
  }
}
