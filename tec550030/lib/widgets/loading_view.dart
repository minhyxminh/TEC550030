import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../models/mascot_mood.dart';
import 'mascot.dart';

/// The tiger naps while data loads.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mascot(mood: MascotMood.sleeping, width: 96, interactive: false),
          SizedBox(height: 12),
          SizedBox(
            width: 72,
            child: LinearProgressIndicator(
              minHeight: 4,
              color: AppColors.primaryOrange,
              backgroundColor: AppColors.sand,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}
