import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/web_back_button_handler.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../screens/agent_home_menu_screen.dart';
import '../tabs/properties_tab.dart';
import '../tabs/finance_tab.dart';
import '../tabs/support_tab.dart';
import '../tabs/building_operations_tab.dart';
import '../tabs/chat_tab.dart';
import '../tabs/users_tab.dart';

class AgentDashboardScreen extends ConsumerStatefulWidget {
  const AgentDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends ConsumerState<AgentDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navController;
  StreamSubscription<void>? _backButtonSubscription;

  // Navigation stack to track screen history (for proper back navigation)
  final List<int> _navigationStack = [0];

  List<Widget> get _pages => [
    AgentHomeMenuScreen(onNavigateToTab: _onTabChanged),
    const PropertiesTab(),
    const FinanceTab(),
    const SupportTab(),
    const BuildingOperationsTab(),
    const UsersTab(),
    const ChatTab(),
  ];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Subscribe to web back button events
    _backButtonSubscription = WebBackButtonHandler.onBackButtonPressed.listen((_) {
      if (mounted) {
        _showBackButtonHint();
      }
    });
  }

  @override
  void dispose() {
    _backButtonSubscription?.cancel();
    _navController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
        _navigationStack.add(index);
      });
    }
  }

  void _goBack() {
    if (_navigationStack.length > 1) {
      setState(() {
        _navigationStack.removeLast();
        _currentIndex = _navigationStack.last;
      });
    } else {
      _showExitWarning(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back, color: AppColors.charcoal, size: 20),
          ),
          onPressed: _goBack,
        ),
        title: Text(
          _getTitle(_currentIndex),
          style: const TextStyle(color: AppColors.charcoal, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: AppColors.charcoal, size: 18),
            label: const Text(
              'Çıkış yap',
              style: TextStyle(color: AppColors.charcoal, fontSize: 13),
            ),
            onPressed: () async {
              await ref.read(authProvider.notifier).logOut();
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _goBack();
          }
        },
        child: AnimatedSwitcher(
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

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Ana Sayfa';
      case 1:
        return 'Binalar';
      case 2:
        return 'Finans';
      case 3:
        return 'Destek';
      case 4:
        return 'Operasyon';
      case 5:
        return 'Çalışanlar';
      case 6:
        return 'Sohbet';
      default:
        return 'Agent';
    }
  }

  void _showBackButtonHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Geri gitmek için ekranın sol üstündeki geri butonunu kullanın',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  void _showExitWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: AppColors.charcoal, size: 22),
            SizedBox(width: 10),
            Text(
              'Çıkış yapmak istiyor musunuz?',
              style: TextStyle(color: AppColors.charcoal, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Uygulamadan çıkmak için sağ üstteki "Çıkış yap" butonunu kullanın.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
