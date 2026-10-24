import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../home/home_screen.dart';
import '../health/health_screen.dart';
import '../chat/chat_entry_screen.dart';
import '../rewards/rewards_screen.dart';
import '../services/services_screen.dart';
import '../profile/profile_screen.dart';

class NavItem {
  final IconData icon, activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

const mainNavItems = [
  NavItem(Icons.home_outlined, Icons.home_rounded, 'Trang chủ'),
  NavItem(Icons.favorite_outline_rounded, Icons.favorite_rounded, 'Sức khỏe'),
  NavItem(Icons.redeem_outlined, Icons.redeem_rounded, 'Đổi thưởng'),
  NavItem(
    Icons.fitness_center_outlined,
    Icons.fitness_center_rounded,
    'Dịch vụ',
  ),
  NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Tài khoản'),
];

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
      extendBody: true,
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
        child: const Icon(Icons.chat_rounded),
      ),
      bottomNavigationBar: GymFlowNavBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
        items: mainNavItems,
      ),
    );
  }
}

/// Floating ink bar; the active tab sits on an orange rounded tile.
class GymFlowNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  const GymFlowNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Container(
      height: 72,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavButton(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    ),
  );
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : const Color(0xFFC9C5D8);
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  scale: selected ? 1.12 : 1,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
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
