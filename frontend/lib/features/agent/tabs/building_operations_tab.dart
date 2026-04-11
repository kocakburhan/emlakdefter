import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/building_operations_provider.dart';
import '../providers/properties_provider.dart';

/// Bina Operasyonları — Şeffaflık Modülü (PRD §4.1.9)
class BuildingOperationsTab extends ConsumerStatefulWidget {
  const BuildingOperationsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<BuildingOperationsTab> createState() => _BuildingOperationsTabState();
}

class _BuildingOperationsTabState extends ConsumerState<BuildingOperationsTab> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buildingOperationsProvider);
    final ops = ref.watch(buildingOperationsProvider.notifier).filteredOps;
    final propsState = ref.watch(propertiesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bina Yönetimi', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, color: AppColors.accent)),
                    const SizedBox(height: 4),
                    Text('Bina Operasyonları', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                  ],
                ),
                _buildAddButton(context),
              ],
            ),
            const SizedBox(height: 16),

            // Özet kartları
            _buildSummaryRow(state),
            const SizedBox(height: 16),

            // Filtreler
            _buildFilterRow(context, state, propsState),
            const SizedBox(height: 16),

            // Liste
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : ops.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: ops.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            if (idx == ops.length) return const SizedBox(height: 100);
                            return _buildOperationCard(context, ops[idx]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accent.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showCreateDialog(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text('Yeni Kayıt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildingOperationsState state) {
    final total = state.operations.fold(0, (sum, op) => sum + op.cost);
    final reflected = state.operations.where((op) => op.isReflectedToFinance).fold(0, (sum, op) => sum + op.cost);
    final unreflected = total - reflected;

    return Row(
      children: [
        Expanded(child: _buildMiniCard('Toplam Maliyet', '₺${_fmt(total)}', AppColors.accent)),
        const SizedBox(width: 10),
        Expanded(child: _buildMiniCard('Finansa Yansıyan', '₺${_fmt(reflected)}', AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _buildMiniCard('Bekleyen', '₺${_fmt(unreflected)}', AppColors.warning)),
      ],
    );
  }

  Widget _buildMiniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, BuildingOperationsState state, AsyncValue<List<PropertyModel>> propsState) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Tümü',
            isSelected: state.propertyFilter == null && state.financeFilter == null,
            onTap: () {
              ref.read(buildingOperationsProvider.notifier).setPropertyFilter(null);
              ref.read(buildingOperationsProvider.notifier).setFinanceFilter(null);
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Finansa Yansıyan',
            isSelected: state.financeFilter == true,
            color: AppColors.success,
            onTap: () {
              ref.read(buildingOperationsProvider.notifier).setFinanceFilter(
                state.financeFilter == true ? null : true,
              );
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Bekleyen',
            isSelected: state.financeFilter == false,
            color: AppColors.warning,
            onTap: () {
              ref.read(buildingOperationsProvider.notifier).setFinanceFilter(
                state.financeFilter == false ? null : false,
              );
            },
          ),
          const SizedBox(width: 8),
          if (propsState.value != null)
            ...propsState.value!.map((p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                label: p.name,
                isSelected: state.propertyFilter == p.id,
                color: AppColors.accent,
                onTap: () {
                  ref.read(buildingOperationsProvider.notifier).setPropertyFilter(
                    state.propertyFilter == p.id ? null : p.id,
                  );
                },
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final chipColor = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipColor.withOpacity(isSelected ? 0 : 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : chipColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.engineering_outlined, size: 64, color: AppColors.textBody.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Hiç bina operasyonu yok', style: TextStyle(color: AppColors.textBody, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Yukarıdaki + ile ilk kaydı oluşturun', style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildOperationCard(BuildContext context, BuildingOperationModel op) {
    final isReflected = op.isReflectedToFinance;
    final dateStr = _formatDate(op.createdAt);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            isReflected ? AppColors.success.withOpacity(0.05) : AppColors.warning.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReflected ? AppColors.success.withOpacity(0.2) : AppColors.warning.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetailSheet(context, op),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isReflected ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isReflected ? Icons.check_circle_outline : Icons.pending_outlined,
                        color: isReflected ? AppColors.success : AppColors.warning,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.title,
                            style: const TextStyle(
                              color: AppColors.textHeader,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (op.description != null && op.description!.isNotEmpty)
                            Text(
                              op.description!,
                              style: TextStyle(color: AppColors.textBody, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₺${_fmt(op.cost)}',
                          style: TextStyle(
                            color: AppColors.textHeader,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isReflected ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isReflected ? 'Finansa Yansıdı' : 'Bekliyor',
                            style: TextStyle(
                              color: isReflected ? AppColors.success : AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textBody.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(dateStr, style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 11)),
                    const SizedBox(width: 12),
                    Icon(Icons.folder_outlined, size: 12, color: AppColors.textBody.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      op.invoiceUrl != null ? 'Fatura var' : 'Fatura yok',
                      style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 11),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.textBody.withOpacity(0.4)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final propsState = ref.read(propertiesProvider);
    final props = propsState.value ?? [];
    if (props.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir mülk ekleyin')),
      );
      return;
    }

    String? selectedPropertyId = props.first.id;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '0');
    bool reflectedToFinance = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.textBody.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Yeni Bina Operasyonu', style: TextStyle(color: AppColors.textHeader, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // Mülk seçimi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedPropertyId,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textHeader),
                      items: props.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) => setSheetState(() => selectedPropertyId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildTextField(titleCtrl, 'Başlık (örn: Asansör Tamiri)', Icons.title),
                const SizedBox(height: 14),
                _buildTextField(descCtrl, 'Açıklama', Icons.description_outlined, maxLines: 2),
                const SizedBox(height: 14),
                _buildTextField(costCtrl, 'Maliyet (TL)', Icons.attach_money, keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                // Finansa yansıt toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Finansa Yansıt', style: TextStyle(color: AppColors.textHeader)),
                      Switch(
                        value: reflectedToFinance,
                        activeColor: AppColors.success,
                        onChanged: (v) => setSheetState(() => reflectedToFinance = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final cost = int.tryParse(costCtrl.text.trim()) ?? 0;
                    final success = await ref.read(buildingOperationsProvider.notifier).createOperation(
                      propertyId: selectedPropertyId!,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      cost: cost,
                      isReflectedToFinance: reflectedToFinance,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kayıt oluşturuldu'), backgroundColor: AppColors.success),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textHeader),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textBody),
          prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, BuildingOperationModel op) {
    final isReflected = op.isReflectedToFinance;
    final dateStr = _formatDate(op.createdAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.textBody.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isReflected ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isReflected ? Icons.check_circle : Icons.pending_outlined,
                    color: isReflected ? AppColors.success : AppColors.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(op.title, style: const TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(dateStr, style: TextStyle(color: AppColors.textBody, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (op.description != null && op.description!.isNotEmpty) ...[
              Text(op.description!, style: const TextStyle(color: AppColors.textBody, height: 1.5)),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Maliyet', style: TextStyle(color: AppColors.textBody)),
                  Text('₺${_fmt(op.cost)}', style: const TextStyle(color: AppColors.textHeader, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Finans Durumu', style: TextStyle(color: AppColors.textBody)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isReflected ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isReflected ? 'Finansa Yansıdı' : 'Bekliyor',
                      style: TextStyle(
                        color: isReflected ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.bold, fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!isReflected)
              ElevatedButton(
                onPressed: () async {
                  final success = await ref.read(buildingOperationsProvider.notifier).updateOperation(
                    id: op.id,
                    isReflectedToFinance: true,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Finansa yansıtıldı'), backgroundColor: AppColors.success),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Finansa Yansıt', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (_) =>
                  AlertDialog(
                    title: const Text('Sil?'),
                    content: const Text('Bu kaydı silmek istediğinize emin misiniz?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(buildingOperationsProvider.notifier).deleteOperation(op.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Kaydı Sil', style: TextStyle(color: AppColors.error)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month - 1]} ${dt.year}';
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}