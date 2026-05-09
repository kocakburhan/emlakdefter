import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/users_provider.dart';

/// Kullanıcılar Ekranı — Animated card selection for employees/tenants/landlords
class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({Key? key}) : super(key: key);

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersProvider);
    final notifier = ref.read(usersProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        title: const Text('Kullanıcılar'),
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.charcoal))
          : Column(
              children: [
                // Animated category cards
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      _buildCategoryCard(
                        context,
                        category: UserCategory.employees,
                        label: 'Çalışanlar',
                        icon: Icons.person,
                        count: state.employees.length,
                        color: AppColors.charcoal,
                        isSelected: state.selectedCategory == UserCategory.employees,
                        onTap: () => notifier.selectCategory(UserCategory.employees),
                      ),
                      const SizedBox(width: 12),
                      _buildCategoryCard(
                        context,
                        category: UserCategory.tenants,
                        label: 'Kiracılar',
                        icon: Icons.home,
                        count: state.tenants.length,
                        color: AppColors.success,
                        isSelected: state.selectedCategory == UserCategory.tenants,
                        onTap: () => notifier.selectCategory(UserCategory.tenants),
                      ),
                      const SizedBox(width: 12),
                      _buildCategoryCard(
                        context,
                        category: UserCategory.landlords,
                        label: 'Ev Sahipleri',
                        icon: Icons.account_balance,
                        count: state.landlords.length,
                        color: AppColors.warning,
                        isSelected: state.selectedCategory == UserCategory.landlords,
                        onTap: () => notifier.selectCategory(UserCategory.landlords),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Category label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _getCategoryLabel(state.selectedCategory),
                      const Spacer(),
                      Text(
                        '${state.currentUsers.length} kullanıcı',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // User list
                Expanded(
                  child: state.currentUsers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          itemCount: state.currentUsers.length,
                          itemBuilder: (context, index) {
                            final user = state.currentUsers[index];
                            return _buildUserCard(user, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required UserCategory category,
    required String label,
    required IconData icon,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: isSelected ? 1.05 : 0.95),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: isSelected ? 1.0 : 0.6),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, _) {
                return Opacity(
                  opacity: 0.4 + (opacity * 0.6),
                  child: child,
                );
              },
            ),
          );
        },
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [color.withValues(alpha: 0.9), color.withValues(alpha: 0.7)]
                    : [color.withValues(alpha: 0.15), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(
              children: [
                Icon(icon, color: isSelected ? Colors.white : color, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _buildUserCard(AppUser user, int index) {
    final statusColor = user.status == 'active' ? AppColors.success : AppColors.textSecondary;
    final statusLabel = user.status == 'active' ? 'Aktif' : 'Pasif';
    final roleColor = user.role == 'employee'
        ? AppColors.charcoal
        : user.role == 'tenant'
            ? AppColors.success
            : AppColors.warning;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 40).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 15 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor.withValues(alpha: 0.8), roleColor.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: const TextStyle(
                            color: AppColors.charcoal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.propertyName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.propertyName!,
                            style: const TextStyle(
                              color: AppColors.charcoal,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (user.email != null && user.email!.isNotEmpty)
                        Expanded(
                          child: Text(
                            user.email!,
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                        Expanded(
                          child: Text(
                            user.phoneNumber!,
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Bu kategoride kullanıcı yok',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCategoryLabel(UserCategory category) {
    switch (category) {
      case UserCategory.employees:
        return const Text(
          'Çalışanlar',
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      case UserCategory.tenants:
        return const Text(
          'Kiracılar',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      case UserCategory.landlords:
        return const Text(
          'Ev Sahipleri',
          style: TextStyle(
            color: AppColors.warning,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
    }
  }
}