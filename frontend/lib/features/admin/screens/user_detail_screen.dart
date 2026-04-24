import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/admin_provider.dart';

/// Kullanıcı Detay Ekranı
class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailScreen({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);
    final user = adminState.selectedUser ?? adminState.users.firstWhere(
      (u) => u['id'] == widget.userId,
      orElse: () => {},
    );

    if (user.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kullanıcı')),
        body: const Center(child: Text('Kullanıcı bulunamadı')),
      );
    }

    final status = user['status'] ?? 'pending';
    final role = user['role'] ?? '';
    final roleLabel = role == 'boss' ? 'Patron' : role == 'employee' ? 'Çalışan' : role;
    final isPending = status == 'pending';
    final isInactive = status == 'inactive';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kullanıcı Detay'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin/users'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _showEditDialog(context, user),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.charcoal.withValues(alpha: 0.1),
                      child: Text(
                        (user['full_name'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user['full_name'] ?? '',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getRoleColor(role).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getRoleIcon(role), size: 16, color: _getRoleColor(role)),
                              const SizedBox(width: 4),
                              Text(
                                roleLabel,
                                style: TextStyle(
                                  color: _getRoleColor(role),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isInactive
                                ? Colors.red.withValues(alpha: 0.2)
                                : isPending
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isInactive
                                ? 'Pasif'
                                : isPending
                                    ? 'İlk giriş bekleniyor'
                                    : 'Aktif',
                            style: TextStyle(
                              color: isInactive
                                  ? Colors.red
                                  : isPending
                                      ? Colors.orange
                                      : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İletişim Bilgileri',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (user['email'] != null) ...[
                      _InfoRow(icon: Icons.email, label: 'Email', value: user['email']),
                      const SizedBox(height: 12),
                    ],
                    if (user['phone_number'] != null)
                      _InfoRow(icon: Icons.phone, label: 'Telefon', value: user['phone_number']),
                    if (user['email'] == null && user['phone_number'] == null)
                      const Text('Henüz iletişim bilgisi yok', style: TextStyle(color: AppColors.slateGray)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Account Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hesap Bilgileri',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (user['created_at'] != null)
                      _InfoRow(
                        icon: Icons.calendar_today,
                        label: 'Oluşturulma',
                        value: _formatDate(user['created_at']),
                      ),
                    if (user['last_login_at'] != null) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.access_time,
                        label: 'Son Giriş',
                        value: _formatDate(user['last_login_at']),
                      ),
                    ],
                    if (user['agency_id'] != null) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.business,
                        label: 'Ofis ID',
                        value: user['agency_id'].toString().substring(0, 8) + '...',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            if (role != 'superadmin') ...[
              Text(
                'İşlemler',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
              ),
              const SizedBox(height: 12),
              if (!isInactive)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block),
                    label: const Text('Pasife Al'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    onPressed: () => _confirmDeactivate(context),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Sil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['full_name']);
    final emailController = TextEditingController(text: user['email'] ?? '');
    final phoneController = TextEditingController(text: user['phone_number'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcı Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Ad Soyad'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Telefon'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Call update API
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Pasife Al'),
        content: const Text('Bu kullanıcı giriş yapamayacak. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              await ref.read(adminProvider.notifier).deactivateUser(widget.userId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Pasife Al'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Sil'),
        content: const Text('Bu kullanıcı silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(adminProvider.notifier).deleteUser(widget.userId);
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/admin/users');
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month}.${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superadmin':
        return Colors.purple;
      case 'boss':
        return AppColors.charcoal;
      case 'employee':
        return AppColors.slateGray;
      case 'tenant':
        return Colors.blue;
      case 'landlord':
        return Colors.green;
      default:
        return AppColors.slateGray;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'superadmin':
        return Icons.admin_panel_settings;
      case 'boss':
        return Icons.business_center;
      case 'employee':
        return Icons.person;
      case 'tenant':
        return Icons.home;
      case 'landlord':
        return Icons.apartment;
      default:
        return Icons.person;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.slateGray),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.slateGray,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}