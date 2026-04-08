import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../tabs/home_tab.dart';
import '../tabs/properties_tab.dart'; // Phase 7.D Added
import '../tabs/finance_tab.dart';    // Phase 7.E Added
import '../tabs/support_tab.dart';    // Phase 7.F Added

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  int _currentIndex = 0;

  // Tüm alt panellerin tam kapasite (Prod-Ready) listesi!
  final List<Widget> _pages = [
    const HomeTab(),       // 1. Özet / Home
    const PropertiesTab(), // 2. Binalarımız
    const FinanceTab(),    // 3. Dosya Okuma ve Tahsilat
    const SupportTab(),    // 4. Müşteri (Kiracı) Masası Aktif!
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sayfayı dolduran içerik alanı (BottomNav seçimine göre gövdeyi değiştirir)
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      
      // Floating, Apple benzeri modern BottomNavigationBar
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (idx) {
               setState(() { _currentIndex = idx; });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent, // Arkaplanı dışarıdaki kutu sağlıyor
            elevation: 0,
            selectedItemColor: AppColors.accent,
            unselectedItemColor: AppColors.textBody.withOpacity(0.5),
            showUnselectedLabels: false,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "Özet"),
              BottomNavigationBarItem(icon: Icon(Icons.business), label: "Binalarım"),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Finans"),
              BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: "Destek"),
            ],
          ),
        ),
      ),
    );
  }
}
