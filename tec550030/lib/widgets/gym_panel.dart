import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/api/api_client.dart';
import '../core/formatters.dart';
import '../models/occupancy.dart';
import '../models/user.dart';
import '../screens/home/qr_scanner_screen.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'catalogue_widgets.dart';
import 'hourly_occupancy_chart.dart';

class GymPanel extends StatefulWidget {
  final User user;
  final VoidCallback? onJoin;
  final VoidCallback? onChanged;
  const GymPanel({
    super.key,
    required this.user,
    this.onJoin,
    this.onChanged,
  });
  String? get gymId => user.homeGymId;
  bool get canCheckIn => user.canCheckIn;
  @override
  State<GymPanel> createState() => _GymPanelState();
}

class _GymPanelState extends State<GymPanel> {
  Map<String, dynamic>? _session;
  int? _occupancy;
  List<HourlyOccupancy> _hourly = [];
  String? _error;
  bool _busy = false;
  bool _choosing = false;
  int _generation = 0;
  Timer? _timer;
  @override
  void didUpdateWidget(covariant GymPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.homeGymId != widget.user.homeGymId ||
      oldWidget.user.hasActiveMembership != widget.user.hasActiveMembership) {
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final requests = <Future<dynamic>>[ApiClient.getJson('/gym/session')];
      if (widget.canCheckIn) {
        requests.add(ApiClient.getJson('/gym/${widget.gymId}/occupancy'));
        requests.add(ApiClient.getJson('/gym/${widget.gymId}/hourly'));
      }
      final data = await Future.wait<dynamic>(requests);
      if (mounted && generation == _generation) {
        setState(() {
          _session = data[0];
            _occupancy = widget.canCheckIn ? data[1]['count'] : null;
            _hourly = !widget.canCheckIn
              ? []
              : (data[2] as List<dynamic>)
              .map((e) => HourlyOccupancy.fromJson(e))
              .toList();
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _act({bool manual = false}) async {
    if (_busy || _choosing) return;
    final sessionId = _session?['id'] as String?;
    if (sessionId == null && !widget.canCheckIn) {
      widget.onJoin?.call();
      return;
    }
    String? token;
    if (sessionId == null) {
      _choosing = true;
      if (manual) {
        token = await showDialog<String>(
          context: context,
          builder: (_) => const _TokenDialog(),
        );
      } else {
        token = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const QRScannerScreen()),
        );
      }
      _choosing = false;
      if (token == null || token.isEmpty || !mounted) return;
    }
    setState(() {
      _busy = true;
      _generation++;
      _error = null;
    });
    try {
      String message;
      if (sessionId != null) {
        await ApiClient.postJson('/gym/check-out', {'session_id': sessionId});
        _session = null;
        message = 'Đã check-out. Hẹn gặp lại bạn!';
      } else {
        final data = await ApiClient.postJson('/gym/check-in', {
          'token': token!,
        });
        _session = data['session'] as Map<String, dynamic>;
        message = data['already_checked_in'] == true
            ? 'Bạn đã check-in.'
            : 'Check-in thành công · +${data['points_earned']} GP';
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Phòng tập hôm nay')),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Cập nhật phòng tập',
            ),
          ],
        ),
        if (_occupancy != null)
          Text(
            '$_occupancy người đang tập',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 8),
        Text(
          _session == null
              ? widget.canCheckIn
                    ? 'Quét QR tại cơ sở của bạn để bắt đầu buổi tập.'
                  : widget.gymId == null
                  ? 'Chọn cơ sở tập để tiếp tục.'
                  : 'Chọn gói tập để bắt đầu check-in.'
              : 'Đang tập từ ${formatDateTime(DateTime.parse(_session!['check_in_at']))}',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppButton(
          text: _session != null
              ? 'Check-out'
              : widget.canCheckIn
              ? 'Quét QR check-in'
              : 'Tham gia',
          isLoading: _busy,
          onPressed: _session != null || widget.canCheckIn
              ? () => _act()
              : widget.onJoin,
        ),
        if (_session == null && widget.canCheckIn)
          TextButton(
            onPressed: _busy ? null : () => _act(manual: true),
            child: const Text('Nhập mã thay cho camera'),
          ),
        const SizedBox(height: 20),
        if (!widget.canCheckIn)
          Text(
            widget.gymId == null
                ? 'Chọn cơ sở để xem occupancy.'
                : 'Chọn gói tập đang hoạt động để xem occupancy.',
          )
        else ...[
          const Text('Số người có mặt trong từng giờ · giờ Việt Nam'),
          const SizedBox(height: 12),
          HourlyOccupancyChart(
            data: _hourly,
            currentHour: DateTime.now()
                .toUtc()
                .add(const Duration(hours: 7))
                .hour,
          ),
        ],
      ],
    ),
  );
}

class _TokenDialog extends StatefulWidget {
  const _TokenDialog();
  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nhập mã tại quầy'),
    content: TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(labelText: 'Mã QR'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Check-in'),
      ),
    ],
  );
}
