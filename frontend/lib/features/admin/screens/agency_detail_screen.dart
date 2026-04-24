import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/admin_service.dart';
import '../providers/admin_provider.dart';

/// Ofis Detay Ekranı
class AgencyDetailScreen extends ConsumerStatefulWidget {
  final String agencyId;

  const AgencyDetailScreen({Key? key, required this.agencyId}) : super(key: key);

  @override
  ConsumerState<AgencyDetailScreen> createState() => _AgencyDetailScreenState();
}

class _AgencyDetailScreenState extends ConsumerState<AgencyDetailScreen> {
  List<Map<String, dynamic>> _agencyUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgencyUsers();
  }

  Future<void> _loadAgencyUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await adminService.getAgencyUsers(widget.agencyId);
      setState(() {
        _agencyUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);
    final agency = adminState.selectedAgency;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(agency?['name'] ?? 'Ofis Detay'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin/agencies'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Agency Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agency?['name'] ?? '',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.charcoal,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: AppColors.slateGray),
                              const SizedBox(width: 4),
                              Text(
                                agency?['address'] ?? 'Adres belirtilmemiş',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.slateGray,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: agency?['subscription_status'] == 'active'
                                      ? Colors.green
                                      : AppColors.slateGray,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (agency?['subscription_status'] ?? 'trial').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
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
                  const SizedBox(height: 24),

                  // Patron section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Patron',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._agencyUsers
                      .where((u) => u['role'] == 'boss')
                      .map((user) => _UserCard(
                            user: user,
                            onTap: () => context.go('/admin/users/${user['id']}'),
                          )),

                  const SizedBox(height: 24),

                  // Employees section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Çalışanlar',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Yeni Çalışan'),
                        onPressed: () => _showAddEmployeeDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_agencyUsers.where((u) => u['role'] == 'employee').isEmpty)
                    const Text('Henüz çalışan eklenmemiş')
                  else
                    ..._agencyUsers
                        .where((u) => u['role'] == 'employee')
                        .map((user) => _UserCard(
                              user: user,
                              onTap: () => context.go('/admin/users/${user['id']}'),
                            )),
                ],
              ),
            ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Çalışan Ekle'),
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
              decoration: const InputDecoration(labelText: 'Email (opsiyonel)'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Telefon (opsiyonel)'),
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
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                // TODO: Call API to create employee
                Navigator.pop(context);
                _loadAgencyUsers();
              }
            },
            child: const Text('Ekle'),
          ),
        ],
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
    final isPending = status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.charcoal.withValues(alpha: 0.1),
          child: Text(
            (user['full_name'] ?? '?')[0].toUpperCase(),
            style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user['full_name'] ?? ''),
        subtitle: Text(
          user['email'] ?? user['phone_number'] ?? '',
          style: const TextStyle(color: AppColors.slateGray),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPending ? Colors.orange : Colors.green,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPending ? 'İlk giriş bekleniyor' : 'Aktif',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}