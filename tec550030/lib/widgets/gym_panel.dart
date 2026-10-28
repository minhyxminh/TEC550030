import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/api/api_client.dart';
import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/occupancy.dart';
import '../models/user.dart';
import '../services/branch_service.dart';
import '../models/gym_branch.dart';
import '../models/mascot_mood.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../screens/home/qr_scanner_screen.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'catalogue_widgets.dart';
import 'checkin_boss_sheet.dart';
import 'decor.dart';
import 'hourly_occupancy_chart.dart';
import 'mascot.dart';

class GymPanel extends StatefulWidget {
  final User user;
  final BranchService branchService;
  final VoidCallback? onJoin;
  final VoidCallback? onChanged;
  const GymPanel({
    super.key,
    required this.user,
    this.branchService = const BranchService(),
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
  List<GymBranch> _branches = [];
  String? get _branchName {
    final id = _session?['gym_id'] as String? ?? widget.gymId;
    for (final branch in _branches) {
      if (branch.id == id) return branch.name;
    }
    return id == null ? null : 'Cơ sở $id';
  }

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
    _loadBranches();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await widget.branchService.getBranches();
      if (mounted) setState(() => _branches = branches);
    } catch (_) {
      /* The attendance panel remains usable if the catalogue is unavailable. */
    }
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
      var mood = MascotMood.celebrate;
      var fresh = false;
      if (sessionId != null) {
        mood = MascotMood.tired;
        await ApiClient.postJson('/gym/check-out', {'session_id': sessionId});
        _session = null;
        message = 'Đã check-out. Hẹn gặp lại bạn!';
      } else {
        final data = await ApiClient.postJson('/gym/check-in', {
          'token': token!,
        });
        _session = data['session'] as Map<String, dynamic>;
        // Only the day's first check-in powers Hổ Flow (+1 HP), the same
        // once-a-day rule as GymPoint.
        fresh =
            data['already_checked_in'] != true &&
            ((data['points_earned'] as num?) ?? 0) > 0;
        message = data['already_checked_in'] == true
            ? 'Bạn đã check-in.'
            : 'Check-in thành công · +${data['points_earned']} GP';
      }
      await _load();
      if (!mounted) return;
      final toast = showMascotToast(context, mood: mood, message: message);
      if (fresh) {
        // After the mascot card: how this check-in powered up Hổ Flow.
        final branch = _branchName;
        final at = DateTime.now();
        toast.then((_) {
          if (mounted) showCheckinBossSheet(context, branch: branch, time: at);
        });
      }
      NotificationService.instance.record(
        kind: NotificationKind.checkin,
        title: sessionId == null ? 'Check-in thành công' : 'Đã check-out',
        // The title already says what happened; add where and the reward.
        body: [
          if (message.contains('+')) 'Nhận ${message.split('· ').last}',
          ?_branchName,
        ].join(' · '),
      );
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
            Container(
              margin: const EdgeInsets.only(right: 14, bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.block,
              ),
              child: const IconTile(
                Icons.location_on_outlined,
                color: AppColors.ink,
                background: AppColors.primaryOrange,
                size: 46,
              ),
            ),
            const Expanded(child: SectionTitle('Phòng tập hôm nay')),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.lavender,
                  foregroundColor: AppColors.ink,
                  fixedSize: const Size(44, 44),
                ),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Cập nhật phòng tập',
              ),
            ),
          ],
        ),
        if (_branchName != null) ...[
          Text(
            _branchName!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
        ],
        if (_occupancy != null)
          Text(
            '$_occupancy người đang tập',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryOrange,
            ),
          ),
        const SizedBox(height: 8),
        DashedBox(
          onTap: _session == null && !widget.canCheckIn ? widget.onJoin : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  _session != null
                      ? Icons.timer_outlined
                      : widget.canCheckIn
                      ? Icons.qr_code_scanner_rounded
                      : Icons.search_rounded,
                  size: 20,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _session == null
                        ? widget.canCheckIn
                              ? 'Quét QR tại ${_branchName ?? 'cơ sở đã chọn'} để bắt đầu buổi tập.'
                              : widget.gymId == null
                              ? 'Chọn cơ sở tập để tiếp tục.'
                              : 'Chọn gói tập để bắt đầu check-in.'
                        : 'Đang tập từ ${formatDateTime(DateTime.parse(_session!['check_in_at']))}',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
                if (_session == null && !widget.canCheckIn)
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.secondaryText,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 12),
        ],
        AppButton(
          text: _session != null
              ? 'Check-out'
              : widget.canCheckIn
              ? 'Quét QR check-in'
              : 'Tham gia',
          isLoading: _busy,
          dark: true,
          icon: _session == null && !widget.canCheckIn
              ? Icons.arrow_forward_rounded
              : null,
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
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 2,
                child: Text(
                  widget.gymId == null
                      ? 'Chọn cơ sở để xem occupancy.'
                      : 'Chọn gói tập đang hoạt động để xem occupancy.',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
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
