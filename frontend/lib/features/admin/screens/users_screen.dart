import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/admin_provider.dart';

/// Tüm Kullanıcılar Listesi
class UsersScreen extends ConsumerWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kullanıcılar'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showCreateUserDialog(context, ref),
          ),
        ],
      ),
      body: adminState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : adminState.users.isEmpty
              ? const Center(child: Text('Henüz kullanıcı eklenmemiş'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: adminState.users.length,
                  itemBuilder: (context, index) {
                    final user = adminState.users[index];
                    return _UserCard(
                      user: user,
                      onTap: () {
                        ref.read(adminProvider.notifier).setSelectedUser(user);
                        context.go('/admin/users/${user['id']}');
                      },
                    );
                  },
                ),
    );
  }

  void _showCreateUserDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'boss';
    String? selectedAgencyId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final adminState = ref.read(adminProvider);
          return AlertDialog(
            title: const Text('Yeni Kullanıcı Ekle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ad Soyad'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email (opsiyonel)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Telefon (opsiyonel)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(value: 'boss', child: Text('Patron')),
                      DropdownMenuItem(value: 'employee', child: Text('Çalışan')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedRole = value ?? 'boss');
                    },
                  ),
                  if (selectedRole == 'boss') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedAgencyId,
                      decoration: const InputDecoration(labelText: 'Ofis Seçin'),
                      items: adminState.agencies.map((a) {
                        return DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text(a['name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedAgencyId = value);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    await ref.read(adminProvider.notifier).createUser(
                          fullName: nameController.text,
                          email: emailController.text.isNotEmpty ? emailController.text : null,
                          phoneNumber: phoneController.text.isNotEmpty ? phoneController.text : null,
                          role: selectedRole,
                          agencyId: selectedAgencyId,
                        );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Oluştur'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = user['status'] ?? 'pending';
    final role = user['role'] ?? '';
    final roleLabel = role == 'boss' ? 'Patron' : role == 'employee' ? 'Çalışan' : role;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role).withValues(alpha: 0.2),
          child: Icon(
            _getRoleIcon(role),
            color: _getRoleColor(role),
          ),
        ),
        title: Text(user['full_name'] ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'] ?? user['phone_number'] ?? '',
              style: const TextStyle(color: AppColors.slateGray),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: _getRoleColor(role),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 'active' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status == 'active' ? 'Aktif' : 'İlk giriş bekleniyor',
                    style: TextStyle(
                      color: status == 'active' ? Colors.green : Colors.orange,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
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