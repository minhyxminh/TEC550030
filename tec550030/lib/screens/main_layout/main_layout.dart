import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../home/home_screen.dart';
import '../health/health_screen.dart';
import '../chat/chat_entry_screen.dart';
import '../rewards/rewards_screen.dart';
import '../services/services_screen.dart';
import '../profile/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  void _selectTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        HomeScreen(onSelectTab: _selectTab),
        const HealthScreen(),
        const RewardsScreen(),
        const ServicesScreen(),
        ProfileScreen(onSelectTab: _selectTab),
      ][_currentIndex],
      floatingActionButton: FloatingActionButton(
        tooltip: 'Chat hỗ trợ',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatEntryScreen()),
        ),
        child: const Icon(Icons.chat_bubble_outline),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: AppColors.secondaryText,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Sức khỏe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_outlined),
            activeIcon: Icon(Icons.card_giftcard),
            label: 'Đổi thưởng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Dịch vụ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
