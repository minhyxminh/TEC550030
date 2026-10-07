import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/point_transaction.dart';
import '../../services/gympoint_service.dart';

import 'package:intl/intl.dart';

class GymPointScreen extends StatefulWidget {
  const GymPointScreen({super.key});

  @override
  State<GymPointScreen> createState() => _GymPointScreenState();
}

class _GymPointScreenState extends State<GymPointScreen> {
  final _gymPointService = GymPointService();
  int _balance = 0;
  List<PointTransaction> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Không dùng API theo yêu cầu
    setState(() {
      _balance = 1250;
      _history = [
        PointTransaction(
          id: '1',
          points: -50,
          reason: 'Đổi Nước suối',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        PointTransaction(
          id: '2',
          points: 10,
          reason: 'Check-in Gym A',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        PointTransaction(
          id: '3',
          points: 10,
          reason: 'Check-in Gym A',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GymPoint Wallet')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryOrange,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32.0),
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.strongOrange,
                          AppColors.primaryOrange,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Tổng điểm hiện tại',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_balance',
                              style: AppTextStyles.display.copyWith(
                                color: Colors.white,
                                fontSize: 48,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'GP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Lịch sử giao dịch',
                        style: AppTextStyles.heading2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _history.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final tx = _history[index];
                        final isPositive = tx.points > 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isPositive
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                            child: Icon(
                              isPositive ? Icons.add : Icons.remove,
                              color: isPositive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          title: Text(
                            tx.reason,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt),
                            style: AppTextStyles.caption,
                          ),
                          trailing: Text(
                            '${isPositive ? '+' : ''}${tx.points}',
                            style: AppTextStyles.heading2.copyWith(
                              color: isPositive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
