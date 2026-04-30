import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';

/// Agent Ana Sayfa — Refined Minimal Luxury Tasarım
///Blur/glow efektleri kaldırıldı, clean shadows ve güçlü tipografi ile şık görünüm
class AgentHomeMenuScreen extends StatelessWidget {
  final Function(int tabIndex) onNavigateToTab;

  const AgentHomeMenuScreen({
    Key? key,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildMenuGrid(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Minimal geometric logo mark
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'E',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                  .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOut),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMLAKDEFTER',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yönetim Paneli',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            fontSize: 26,
                          ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideX(begin: 0.08, end: 0, delay: 100.ms, duration: 400.ms, curve: Curves.easeOut),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Bir seçenek belirleyin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final cards = _buildCards(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Row 1: 3 cards
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
              const SizedBox(width: 10),
              Expanded(child: cards[2]),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: 3 cards
          Row(
            children: [
              Expanded(child: cards[3]),
              const SizedBox(width: 10),
              Expanded(child: cards[4]),
              const SizedBox(width: 10),
              Expanded(child: cards[5]),
            ],
          ),
          const SizedBox(height: 10),
          // Row 3: 1 card
          Row(
            children: [
              Expanded(child: cards[6]),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context) {
    return [
      // Özet — Dashboard KPIs
      _MenuCardClean(
        title: 'Özet',
        subtitle: 'KPI\'lar & Rapor',
        icon: Icons.dashboard_rounded,
        color: AppColors.charcoal,
        index: 0,
        onTap: () => onNavigateToTab(0),
      ),

      // Binalar — Properties
      _MenuCardClean(
        title: 'Binalar',
        subtitle: 'Portföy Yönetimi',
        icon: Icons.business_rounded,
        color: AppColors.slateGray,
        index: 1,
        onTap: () => onNavigateToTab(1),
      ),

      // Finans — Finance
      _MenuCardClean(
        title: 'Finans',
        subtitle: 'Tahsilat & Rapor',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.success,
        index: 2,
        onTap: () => onNavigateToTab(2),
        badge: 'Yeni',
        badgeColor: AppColors.success,
      ),

      // Destek — Support
      _MenuCardClean(
        title: 'Destek',
        subtitle: 'Talep & Şikayet',
        icon: Icons.support_agent_rounded,
        color: AppColors.info,
        index: 3,
        onTap: () => onNavigateToTab(3),
        badge: '3',
        badgeColor: AppColors.error,
      ),

      // Operasyon — Building Operations
      _MenuCardClean(
        title: 'Operasyon',
        subtitle: 'Bakım & Onarım',
        icon: Icons.engineering_rounded,
        color: AppColors.warning,
        index: 4,
        onTap: () => onNavigateToTab(4),
      ),

      // Çalışanlar — Employees
      _MenuCardClean(
        title: 'Çalışanlar',
        subtitle: 'Personel Yönetimi',
        icon: Icons.people_rounded,
        color: const Color(0xFF6B5B4F),
        index: 5,
        onTap: () => onNavigateToTab(5),
      ),

      // Sohbet — Chat
      _MenuCardClean(
        title: 'Sohbet',
        subtitle: 'Mesajlaşmalar',
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF5B6B8B),
        index: 6,
        onTap: () => onNavigateToTab(6),
        badge: 'Yeni',
        badgeColor: const Color(0xFF5B6B8B),
      ),
    ];
  }
}

/// Temiz, blur-free menü kartı
class _MenuCardClean extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int index;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  const _MenuCardClean({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.index,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  State<_MenuCardClean> createState() => _MenuCardCleanState();
}

class _MenuCardCleanState extends State<_MenuCardClean> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + Badge Row
              Row(
                children: [
                  // Solid icon container — no blur
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  if (widget.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (widget.badgeColor ?? widget.color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.badge!,
                        style: TextStyle(
                          color: widget.badgeColor ?? widget.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 4),
              // Subtitle
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * widget.index),
          duration: 350.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          delay: Duration(milliseconds: 50 * widget.index),
          duration: 350.ms,
          curve: Curves.easeOut,
        );
  }
}