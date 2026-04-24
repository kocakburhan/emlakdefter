import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/admin_provider.dart';

/// Admin Dashboard - Ana admin paneli
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load initial data
    Future.microtask(() {
      ref.read(adminProvider.notifier).loadAgencies();
      ref.read(adminProvider.notifier).loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              // TODO: Logout
              context.go('/');
            },
          ),
        ],
      ),
      body: adminState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stats Row
                  Row(
                    children: [
                      _StatCard(
                        title: 'Ofisler',
                        value: '${adminState.agencies.length}',
                        icon: Icons.business,
                        color: AppColors.charcoal,
                        onTap: () => context.go('/admin/agencies'),
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        title: 'Kullanıcılar',
                        value: '${adminState.users.length}',
                        icon: Icons.people,
                        color: AppColors.slateGray,
                        onTap: () => context.go('/admin/users'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  Text(
                    'Hızlı İşlemler',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    title: 'Yeni Ofis Ekle',
                    subtitle: 'Yeni emlak ofisi ve patron oluştur',
                    icon: Icons.add_business,
                    onTap: () => context.go('/admin/agencies/new'),
                  ),
                  _ActionCard(
                    title: 'Yeni Patron Ekle',
                    subtitle: 'Yeni patron oluştur ve ofise bağla',
                    icon: Icons.person_add,
                    onTap: () => _showCreateUserDialog(context, 'boss'),
                  ),
                  _ActionCard(
                    title: 'Tüm Kullanıcıları Gör',
                    subtitle: 'Patron ve çalışanları listele',
                    icon: Icons.people_outline,
                    onTap: () => context.go('/admin/users'),
                  ),
                ],
              ),
            ),
    );
  }

  void _showCreateUserDialog(BuildContext context, String role) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedAgencyId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final adminState = ref.read(adminProvider);
          return AlertDialog(
            title: Text('Yeni ${role == 'boss' ? 'Patron' : 'Çalışan'} Ekle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (opsiyonel)',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (opsiyonel)',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  if (role == 'boss') ...[
                    DropdownButtonFormField<String>(
                      value: selectedAgencyId,
                      decoration: const InputDecoration(
                        labelText: 'Ofis Seçin',
                      ),
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
                          email: emailController.text.isNotEmpty
                              ? emailController.text
                              : null,
                          phoneNumber: phoneController.text.isNotEmpty
                              ? phoneController.text
                              : null,
                          role: role,
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white70, size: 32),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.charcoal),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}