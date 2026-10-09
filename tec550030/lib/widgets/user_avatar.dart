import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  const UserAvatar({super.key, this.url, this.radius = 38});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.primaryOrange,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        size: radius * 1.1,
        color: Colors.white,
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    return Semantics(
      label: 'Ảnh đại diện',
      image: true,
      child: ClipOval(
        child: SizedBox(
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
        ),
      ),
    );
  }
}
