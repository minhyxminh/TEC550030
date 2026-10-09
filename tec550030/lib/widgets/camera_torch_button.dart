import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme/app_colors.dart';

class CameraTorchButton extends StatelessWidget {
  final MobileScannerController controller;
  const CameraTorchButton({super.key, required this.controller});
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<MobileScannerState>(
    valueListenable: controller,
    builder: (context, state, child) {
      final isOn = state.torchState == TorchState.on;
      final available =
          state.isInitialized &&
          state.isRunning &&
          state.torchState != TorchState.unavailable;
      return IconButton(
        color: AppColors.darkText,
        iconSize: 32,
        // Show the action: the crossed bolt turns an active flash off.
        icon: Icon(isOn ? Icons.flash_off : Icons.flash_on),
        tooltip: available
            ? (isOn ? 'Tắt flash' : 'Bật flash')
            : 'Flash không khả dụng',
        onPressed: !available
            ? null
            : () async {
                try {
                  await controller.toggleTorch();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Không thể đổi trạng thái flash. Vui lòng thử lại.',
                        ),
                      ),
                    );
                  }
                }
              },
      );
    },
  );
}
