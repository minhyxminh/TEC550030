import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/gympoint.dart';
import '../../models/point_transaction.dart';
import '../../services/gympoint_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';

class GymPointScreen extends StatefulWidget {
  const GymPointScreen({super.key});
  @override
  State<GymPointScreen> createState() => _GymPointScreenState();
}

class _GymPointScreenState extends State<GymPointScreen> {
  final _service = GymPointService();
  int _balance = 0, _generation = 0;
  int _historyOffset = 0;
  List<PointTransaction> _history = [];
  bool _loading = true, _loadingMore = false, _hasMore = false;
  String? _error, _moreError;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _loadingMore = false;
    });
    try {
      final data = await Future.wait<Object>([
        _service.getBalance(),
        _service.getHistory(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _balance = (data[0] as GymPointBalance).balance;
        _history = data[1] as List<PointTransaction>;
        _historyOffset = _history.length;
        _hasMore = _history.length == 20;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await _service.getHistory(offset: _historyOffset);
      if (!mounted || generation != _generation) return;
      setState(() {
        // Deduplicate if new transactions shifted the offset between requests.
        final ids = _history.map((item) => item.id).toSet();
        _history.addAll(page.where((item) => !ids.contains(item.id)));
        _historyOffset += page.length;
        _hasMore = page.length == 20;
        _loadingMore = false;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _moreError = error.toString();
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ví GymPoint')),
    body: _loading
        ? const LoadingView()
        : _error != null
        ? ErrorState(message: _error!, onRetry: _reload)
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    PointBalanceCard(balance: _balance),
                    const SizedBox(height: 24),
                    const SectionTitle(
                      'Lịch sử điểm',
                      subtitle: 'Theo dõi các lần cộng và sử dụng GymPoint',
                    ),
                    if (_history.isEmpty)
                      const AppCard(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: EmptyState(
                            message: 'Chưa có giao dịch điểm.\nCác giao dịch của bạn sẽ hiển thị tại đây.',
                          ),
                        ),
                      )
                    else
                      ..._history.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      (item.points > 0
                                              ? AppColors.success
                                              : AppColors.error)
                                          .withValues(alpha: 0.1),
                                  child: Icon(
                                    item.points > 0 ? Icons.add : Icons.remove,
                                    color: item.points > 0
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.reason,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formatDateTime(item.createdAt),
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.type == 'EARN'
                                            ? 'Tích điểm'
                                            : 'Đổi thưởng',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${item.points > 0 ? '+' : ''}${formatNumber(item.points)} GP',
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: item.points > 0
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_moreError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _moreError!,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    if (_hasMore)
                      AppButton(
                        text: _moreError == null
                            ? 'Xem thêm giao dịch'
                            : 'Thử tải thêm',
                        isSecondary: true,
                        isLoading: _loadingMore,
                        onPressed: _loadMore,
                      ),
                  ],
                ),
              ),
            ),
          ),
  );
}
