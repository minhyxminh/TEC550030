import 'package:material_ui/material_ui.dart';

import '../core/theme/app_text_styles.dart';
import '../models/mascot_mood.dart';
import 'mascot.dart';

class EmptyState extends StatelessWidget {
  /// First line is shown as the title, any following lines as the description.
  final String message;

  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final split = message.indexOf('\n');
    final title = split < 0 ? message : message.substring(0, split);
    final detail = split < 0 ? null : message.substring(split + 1);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Mascot(mood: MascotMood.thinking, width: 112),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.heading2,
            textAlign: TextAlign.center,
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
