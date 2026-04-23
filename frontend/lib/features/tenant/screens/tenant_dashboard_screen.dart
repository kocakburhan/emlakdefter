import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../tabs/tenant_home_tab.dart';
import '../tabs/tenant_finance_tab.dart';
import '../tabs/tenant_support_tab.dart';
import '../tabs/tenant_documents_tab.dart';
import '../tabs/tenant_building_ops_tab.dart';
import '../tabs/tenant_chat_tab.dart';
import '../tabs/tenant_explore_tab.dart';

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  int _currentIndex = 0;

  void navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  List<Widget> get _pages => [
    const TenantHomeTab(),
    const TenantFinanceTab(),
    const TenantSupportTab(),
    const TenantDocumentsTab(),
    const TenantBuildingOpsTab(),
    TenantChatTab(onNavigateToTab: navigateToTab),
    TenantExploreTab(onNavigateToTab: navigateToTab),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 30),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha:0.9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.charcoal.withValues(alpha:0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoal.withValues(alpha:0.4),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (idx) => setState(() => _currentIndex = idx),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.charcoal,
            unselectedItemColor: AppColors.textSecondary.withValues(alpha:0.5),
            showUnselectedLabels: false,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Evim"),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: "Ödemeler"),
              BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: "Destek"),
              BottomNavigationBarItem(icon: Icon(Icons.folder_special_outlined), label: "Belge"),
              BottomNavigationBarItem(icon: Icon(Icons.visibility_outlined), label: "Bina"),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Sohbet"),
              BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: "Keşfet"),
            ],
          ),
        ),
      ),
    );
  }
}
