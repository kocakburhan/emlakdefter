import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';
import '../screens/agent_home_menu_screen.dart';
import '../tabs/properties_tab.dart';
import '../tabs/finance_tab.dart';
import '../tabs/support_tab.dart';
import '../tabs/building_operations_tab.dart';
import '../tabs/chat_tab.dart';
import '../tabs/employees_tab.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navController;

  List<Widget> get _pages => [
    AgentHomeMenuScreen(onNavigateToTab: _onTabChanged),
    const PropertiesTab(),
    const FinanceTab(),
    const SupportTab(),
    const BuildingOperationsTab(),
    const EmployeesTab(),
    const ChatTab(),
  ];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 72,
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onTabChanged,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: AppColors.charcoal,
                unselectedItemColor: AppColors.textTertiary,
                showUnselectedLabels: true,
                selectedLabelStyle: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: Theme.of(context).textTheme.labelSmall,
                items: [
                  _buildNavItem(
                    Icons.home_outlined,
                    Icons.home,
                    "Ana Sayfa",
                    0,
                  ),
                  _buildNavItem(
                    Icons.business_outlined,
                    Icons.business,
                    "Binalar",
                    1,
                  ),
                  _buildNavItem(
                    Icons.account_balance_wallet_outlined,
                    Icons.account_balance_wallet,
                    "Finans",
                    2,
                  ),
                  _buildNavItem(
                    Icons.support_agent_outlined,
                    Icons.support_agent,
                    "Destek",
                    3,
                  ),
                  _buildNavItem(
                    Icons.engineering_outlined,
                    Icons.engineering,
                    "Operasyon",
                    4,
                  ),
                  _buildNavItem(
                    Icons.people_outline,
                    Icons.people,
                    "Çalışanlar",
                    5,
                  ),
                  _buildNavItem(
                    Icons.chat_bubble_outline,
                    Icons.chat_bubble,
                    "Sohbet",
                    6,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.charcoal.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(isSelected ? activeIcon : icon, size: 22),
      ),
      label: label,
    );
  }
}
