import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/hourly_occupancy_chart.dart';
import '../../services/gym_service.dart';
import '../../services/gympoint_service.dart';
import '../../models/occupancy.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _gymService = GymService();
  final _pointService = GymPointService();

  bool _isLoading = true;
  int _currentOccupancy = 0;
  int _gymPointBalance = 0;
  List<HourlyOccupancy> _hourlyData = [];

  // TODO: Update gymId when multiple gyms are supported
  final String _gymId = '1';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Không dùng API theo yêu cầu, render ngay giao diện
    setState(() {
      _currentOccupancy = 47;
      _gymPointBalance = 1250;
      _hourlyData = [
        HourlyOccupancy(hour: 6, count: 12),
        HourlyOccupancy(hour: 7, count: 30),
        HourlyOccupancy(hour: 8, count: 45),
        HourlyOccupancy(hour: 9, count: 32),
        HourlyOccupancy(hour: 10, count: 20),
        HourlyOccupancy(hour: 11, count: 15),
        HourlyOccupancy(hour: 12, count: 47),
      ];
      _isLoading = false;
    });
  }

  Future<void> _scanQR() async {
    final qrToken = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (qrToken != null) {
      _handleCheckInOut(qrToken);
    }
  }

  Future<void> _handleCheckInOut(String token) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _gymService.checkInOut(token);
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        _showSuccessDialog(
          result['message'] ?? 'Thành công',
          result['status'] == 'IN',
        );
        _loadData(); // reload data to get updated points and occupancy
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showSuccessDialog(String message, bool isIn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              isIn ? 'Check-in thành công' : 'Check-out thành công',
              style: AppTextStyles.heading2,
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Lỗi', style: AppTextStyles.heading2),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryOrange,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOrange,
                  ),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chào bạn,', style: AppTextStyles.caption),
                              Text(
                                'Hội viên GymFlow',
                                style: AppTextStyles.heading1,
                              ),
                            ],
                          ),
                          const CircleAvatar(
                            backgroundColor: AppColors.primaryOrange,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Occupancy Card
                      AppCard(
                        child: Column(
                          children: [
                            const Text(
                              'SỐ NGƯỜI ĐANG TẬP',
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$_currentOccupancy',
                                  style: AppTextStyles.display.copyWith(
                                    fontSize: 48,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'người',
                                  style: AppTextStyles.heading2,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AppButton(text: 'SCAN QR', onPressed: _scanQR),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // GymPoint Summary
                      AppCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.gymPointYellow.withValues(
                                      alpha: 0.2,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.stars,
                                    color: AppColors.gymPointYellow,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'GymPoint',
                                      style: AppTextStyles.caption,
                                    ),
                                    Text(
                                      '$_gymPointBalance',
                                      style: AppTextStyles.heading2,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.secondaryText,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hourly Chart
                      const Text(
                        'Biểu đồ trong ngày',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 16),
                      AppCard(
                        child: HourlyOccupancyChart(
                          data: _hourlyData,
                          currentHour: DateTime.now().hour,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
