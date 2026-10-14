import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/gym_branch.dart';
import '../../services/branch_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/catalogue_widgets.dart';

class BranchSelectionScreen extends StatefulWidget {
  final BranchService branchService;
  final LocationService locationService;

  const BranchSelectionScreen({
    super.key,
    this.branchService = const BranchService(),
    this.locationService = const LocationService(),
  });

  @override
  State<BranchSelectionScreen> createState() => _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends State<BranchSelectionScreen> {
  List<GymBranch> _branches = [];
  LocationResult _location = const LocationResult(denied: true);
  bool _loading = true;
  String? _error;
  String? _savingGymId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locationFuture = widget.locationService.getCurrentLocation().catchError(
        (_) => const LocationResult(denied: true),
      );
      final branchesFuture = widget.branchService.getBranches();
      final results = await Future.wait<Object>([locationFuture, branchesFuture]);
      final location = results[0] as LocationResult;
      final branches = results[1] as List<GymBranch>;
      final located = location.hasPosition
          ? branches
                .map(
                  (branch) => branch.withDistance(
                    widget.locationService.distanceKm(
                      location.latitude!,
                      location.longitude!,
                      branch.latitude,
                      branch.longitude,
                    ),
                  ),
                )
                .toList()
          : branches;
      if (location.hasPosition) {
        located.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
      }
      if (!mounted) return;
      setState(() {
        _location = location;
        _branches = located;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _select(GymBranch branch) async {
    if (_savingGymId != null) return;
    setState(() {
      _savingGymId = branch.id;
      _error = null;
    });
    try {
      await widget.branchService.selectHomeGym(branch.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _savingGymId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn cơ sở tập')),
    body: _loading
        ? const LoadingView()
        : _error != null && _branches.isEmpty
        ? ErrorState(message: _error!, onRetry: _load)
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionTitle(
                'Cơ sở GymFlow',
                subtitle: 'Chọn nơi bạn muốn tập luyện.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                ),
              if (_location.permanentlyDenied)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vị trí bị tắt. Bạn vẫn có thể chọn cơ sở.'),
                      TextButton.icon(
                        onPressed: widget.locationService.openAppSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Mở cài đặt ứng dụng'),
                      ),
                    ],
                  ),
                )
              else if (_location.serviceDisabled)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dịch vụ vị trí đang tắt. Bạn vẫn có thể chọn cơ sở.'),
                      TextButton.icon(
                        onPressed: widget.locationService.openLocationSettings,
                        icon: const Icon(Icons.location_searching),
                        label: const Text('Mở cài đặt vị trí'),
                      ),
                    ],
                  ),
                )
              else if (_location.denied)
                const AppCard(
                  child: Text('Không có quyền vị trí. Bạn vẫn có thể chọn cơ sở.'),
                ),
              if (_branches.isEmpty)
                const AppCard(child: Text('Chưa có cơ sở đang hoạt động.')),
              ..._branches.map(
                (branch) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: _savingGymId == null ? () => _select(branch) : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(branch.name, style: AppTextStyles.heading2),
                              const SizedBox(height: 4),
                              Text(branch.address, style: AppTextStyles.body),
                              const SizedBox(height: 4),
                              Text(
                                '${branch.district} · ${branch.openingHours}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        if (branch.distanceKm != null)
                          Text(
                            '${branch.distanceKm!.toStringAsFixed(1)} km',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.deepOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (_savingGymId == branch.id) ...[
                          const SizedBox(width: 8),
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}
