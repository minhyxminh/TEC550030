import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../models/reward.dart';
import '../../services/reward_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _rewardService = RewardService();
  List<Reward> _rewards = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    // Không dùng API theo yêu cầu
    setState(() {
      _rewards = [
        Reward(
          id: '1',
          name: 'Nước suối',
          description: 'Nước suối Dasani 500ml',
          points: 50,
          stock: 100,
          imageUrl: 'https://via.placeholder.com/150/0000FF/808080?Text=Water',
        ),
        Reward(
          id: '2',
          name: 'Khăn tập',
          description: 'Khăn cotton cao cấp',
          points: 150,
          stock: 20,
          imageUrl: 'https://via.placeholder.com/150/FF0000/FFFFFF?Text=Towel',
        ),
      ];
      _isLoading = false;
    });
  }

  void _showRewardDetail(Reward reward) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(reward.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(reward.name, style: AppTextStyles.heading1),
              const SizedBox(height: 8),
              Text(reward.description, style: AppTextStyles.body),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${reward.points} GymPoint',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.gymPointYellow,
                    ),
                  ),
                  Text(
                    'Còn lại: ${reward.stock}',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Đổi ngay',
                onPressed: reward.stock > 0
                    ? () {
                        Navigator.pop(context);
                        _redeemReward(reward);
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _redeemReward(Reward reward) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _rewardService.redeemReward(reward.id);
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đổi thưởng thành công!')));
        _loadRewards(); // Refresh to update stock
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi thưởng')),
      body: RefreshIndicator(
        onRefresh: _loadRewards,
        color: AppColors.primaryOrange,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.7,
                ),
                itemCount: _rewards.length,
                itemBuilder: (context, index) {
                  final reward = _rewards[index];
                  return AppCard(
                    padding: const EdgeInsets.all(8),
                    onTap: () => _showRewardDetail(reward),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.warmBackground,
                              image: DecorationImage(
                                image: NetworkImage(reward.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reward.name,
                          style: AppTextStyles.heading2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${reward.points} GP',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.gymPointYellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Còn: ${reward.stock}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
