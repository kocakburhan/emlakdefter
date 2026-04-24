import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/admin_provider.dart';

/// Emlak Ofisleri Listesi
class AgenciesScreen extends ConsumerWidget {
  const AgenciesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emlak Ofisleri'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAgencyDialog(context, ref),
        backgroundColor: AppColors.charcoal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: adminState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : adminState.agencies.isEmpty
              ? const Center(child: Text('Henüz ofis eklenmemiş'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: adminState.agencies.length,
                  itemBuilder: (context, index) {
                    final agency = adminState.agencies[index];
                    return _AgencyCard(
                      agency: agency,
                      onTap: () {
                        ref.read(adminProvider.notifier).setSelectedAgency(agency);
                        context.go('/admin/agencies/${agency['id']}');
                      },
                      onDelete: () => _confirmDelete(context, ref, agency['id']),
                    );
                  },
                ),
    );
  }

  void _showCreateAgencyDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Ofis Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Ofis Adı'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Adres'),
              maxLines: 2,
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
                await ref.read(adminProvider.notifier).createAgency(
                      name: nameController.text,
                      address: addressController.text,
                    );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String agencyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ofisi Sil'),
        content: const Text('Bu ofisi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(adminProvider.notifier).deleteAgency(agencyId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _AgencyCard extends StatelessWidget {
  final Map<String, dynamic> agency;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AgencyCard({
    required this.agency,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, color: AppColors.charcoal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency['name'] ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                    ),
                    if (agency['address'] != null)
                      Text(
                        agency['address'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slateGray,
                            ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(agency['subscription_status']),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        agency['subscription_status'] ?? 'trial',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.slateGray;
    }
  }
}