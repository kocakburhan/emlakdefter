import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../tabs/tenant_home_tab.dart';
import '../tabs/tenant_finance_tab.dart'; // Phase 8.B Added
import '../tabs/tenant_support_tab.dart'; // Phase 8.C Added

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  int _currentIndex = 0;

  // Lort paneli gibi yoğun değil, basit "B2C Müşteri Odaklı" sade liste. 3 Menü tam teşekküllü aktif!
  final List<Widget> _pages = [
    const TenantHomeTab(), // Ana Özet ve Koca Borç Göstergesi
    const TenantFinanceTab(), // B2C Finans Ekstresi Yükleme Aktif!
    const TenantSupportTab(), // B2C Destek Şikayet Açma Aktif!
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      
      // Kiracı paneline çok daha yumuşak, sıcak ve Apple-vari bir (Cam) menü çiziyoruz:
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 30), // Daha ince bir Margin
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.9), // Gece Siyahı / Cam Teması
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1.5), // Hafif Mavi Kontur
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4), // Işıltılı Gölge
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (idx) {
               setState(() { _currentIndex = idx; });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent, // Arka plan dış Container'dan.
            elevation: 0,
            selectedItemColor: AppColors.accent,
            unselectedItemColor: AppColors.textBody.withOpacity(0.5),
            showUnselectedLabels: false,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Evim"),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: "Ödemeler"),
              BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: "Destek"),
            ],
          ),
        ),
      ),
    );
  }
}
