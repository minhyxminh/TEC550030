import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../services/biometric_service.dart';
import 'app_card.dart';

class BiometricSetting extends StatefulWidget {
  /// Renders as a bare row for use inside a grouped list.
  final bool embedded;
  const BiometricSetting({super.key, this.embedded = false});
  @override
  State<BiometricSetting> createState() => _BiometricSettingState();
}

class _BiometricSettingState extends State<BiometricSetting> {
  final _service = BiometricService();
  bool _enabled = false, _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.enabled;
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _busy = false;
      });
    }
  }

  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    try {
      final ok = await _service.setEnabled(value);
      if (!mounted) return;
      if (ok) {
        setState(() => _enabled = value);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cần ghi nhớ đăng nhập và xác thực sinh trắc học đã cài trên thiết bị. Bạn vẫn có thể dùng mật khẩu.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tile = SwitchListTile(
      contentPadding: widget.embedded
          ? const EdgeInsets.symmetric(horizontal: 16)
          : EdgeInsets.zero,
      secondary: const IconTile(
        Icons.fingerprint_rounded,
        color: AppColors.success,
        background: AppColors.mint,
      ),
      title: const Text('Mở nhanh bằng sinh trắc học'),
      subtitle: const Text('Xác thực khi mở lại phiên đã ghi nhớ.'),
      value: _enabled,
      onChanged: _busy ? null : _change,
    );
    return widget.embedded ? tile : AppCard(child: tile);
  }
}
