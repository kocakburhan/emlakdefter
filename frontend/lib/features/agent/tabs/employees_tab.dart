import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/employees_provider.dart';

/// Çalışanlar Tab
class EmployeesTab extends ConsumerStatefulWidget {
  const EmployeesTab({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends ConsumerState<EmployeesTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(employeeProvider.notifier).loadEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final employeeState = ref.watch(employeeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Çalışanlar'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddEmployeeDialog(context),
          ),
        ],
      ),
      body: employeeState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : employeeState.employees.isEmpty
          ? _buildEmptyState()
          : _buildEmployeeList(employeeState.employees),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEmployeeDialog(context),
        backgroundColor: AppColors.charcoal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.slateGray),
          const SizedBox(height: 16),
          Text(
            'Henüz çalışan eklenmemiş',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.slateGray),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni çalışan eklemek için + butonuna tıklayın',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slateGray),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList(List<Map<String, dynamic>> employees) {
    return RefreshIndicator(
      color: AppColors.charcoal,
      onRefresh: () async {
        await ref.read(employeeProvider.notifier).loadEmployees();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: employees.length,
        itemBuilder: (context, index) {
          final employee = employees[index];
          return _EmployeeCard(
            employee: employee,
            onTap: () => _showEmployeeDetail(context, employee),
            onDeactivate: () => _confirmDeactivate(context, employee['id']),
            onDelete: () => _confirmDelete(context, employee['id']),
          );
        },
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Yeni Çalışan Ekle'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        hintText: 'Çalışanın adı soyadı',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ad Soyad zorunludur';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'ornek@mail.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        final phone = phoneController.text.trim();
                        if (email.isEmpty && phone.isEmpty) {
                          return 'Email veya telefon girilmelidir';
                        }
                        if (email.isNotEmpty &&
                            (!email.contains('@') || !email.contains('.'))) {
                          return 'Geçerli bir email adresi girin';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        hintText: '5xx xxx xx xx',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        final email = emailController.text.trim();
                        if (phone.isEmpty && email.isEmpty) {
                          return 'Email veya telefon girilmelidir';
                        }
                        if (phone.isNotEmpty) {
                          final digits = phone.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 10 || !digits.startsWith('5')) {
                            return 'Geçerli bir Türkiye numarası (5xxxxxxxxx)';
                          }
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Şifre (Opsiyonel)',
                        hintText: 'Direct login için',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (value.length < 8) {
                            return 'Şifre en az 8 karakter olmalı';
                          }
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return 'En az bir büyük harf gerekli';
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return 'En az bir rakam gerekli';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '* Email veya telefondan en az biri girilmelidir.\n* Şifre girilirse direkt giriş yapılabilir.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await ref
                        .read(employeeProvider.notifier)
                        .createEmployee(
                          fullName: nameController.text.trim(),
                          email: emailController.text.trim().isNotEmpty
                              ? emailController.text.trim()
                              : null,
                          phoneNumber: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                          password: passwordController.text.trim().isNotEmpty
                              ? passwordController.text.trim()
                              : null,
                        );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Ekle'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEmployeeDetail(
    BuildContext context,
    Map<String, dynamic> employee,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.charcoal.withValues(alpha: 0.1),
                  child: Text(
                    (employee['full_name'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['full_name'] ?? '',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            employee['status'],
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusLabel(employee['status']),
                          style: TextStyle(
                            color: _getStatusColor(employee['status']),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (employee['email'] != null)
              _DetailRow(
                icon: Icons.email,
                label: 'Email',
                value: employee['email'],
              ),
            if (employee['phone_number'] != null)
              _DetailRow(
                icon: Icons.phone,
                label: 'Telefon',
                value: employee['phone_number'],
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block),
                    label: const Text('Pasife Al'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeactivate(context, employee['id']);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(context, employee['id']);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çalışanı Pasife Al'),
        content: const Text('Bu çalışan giriş yapamayacak. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              await ref
                  .read(employeeProvider.notifier)
                  .deactivateEmployee(userId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Pasife Al'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çalışanı Sil'),
        content: const Text('Bu çalışan silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(employeeProvider.notifier).deleteEmployee(userId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'inactive':
        return 'Pasif';
      default:
        return 'İlk giriş bekleniyor';
    }
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onTap;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;

  const _EmployeeCard({
    required this.employee,
    required this.onTap,
    required this.onDeactivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = employee['status'] ?? 'pending';
    final isPending = status == 'pending';
    final isInactive = status == 'inactive';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.charcoal.withValues(alpha: 0.1),
                child: Text(
                  (employee['full_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee['full_name'] ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee['email'] ?? employee['phone_number'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slateGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'inactive':
        return 'Pasif';
      default:
        return 'İlk giriş bekleniyor';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
      ),
    );
  }
}
