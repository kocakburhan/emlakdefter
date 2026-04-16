import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_storage.dart';

/// Mali Rapor Ekranı — PRD §4.1.6
/// "Refined Ledger" — Premium dark muhasebe teması
/// Staggered animations, mülk bağlama, kaynak etiketleri, kategori yönetimi
class MaliRaporScreen extends ConsumerStatefulWidget {
  const MaliRaporScreen({super.key});

  @override
  ConsumerState<MaliRaporScreen> createState() => _MaliRaporScreenState();
}

class _MaliRaporScreenState extends ConsumerState<MaliRaporScreen>
    with TickerProviderStateMixin {
  // ─── Data ───────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _report;
  List<dynamic> _transactions = [];
  List<dynamic> _properties = [];
  bool _isLoading = true;
  String? _error;
  int _pendingTxCount = 0;

  // ─── Filters ────────────────────────────────────────────────────────────────
  String _selectedPeriod = 'this_month';
  String? _selectedCategory;

  // ─── Chart ─────────────────────────────────────────────────────────────────
  List<dynamic> _monthlyData = [];
  List<dynamic> _categoryBreakdown = [];
  int _touchedCategoryIndex = -1;

  // ─── Animations ────────────────────────────────────────────────────────────
  late AnimationController _staggerController;

  // ─── Form ─────────────────────────────────────────────────────────────────
  final _formAmountController = TextEditingController();
  final _formDescController = TextEditingController();
  final _formCustomCategoryController = TextEditingController();
  String _formType = 'income';
  String _formCategory = 'rent';
  bool _isCustomCategory = false;
  String? _formPropertyId;

  // ─── Categories (PRD §4.1.6-B — esnek kategori yönetimi) ───────────────────
  static const _incomeCategories = [
    {'value': 'rent', 'label': 'Kira', 'icon': Icons.home},
    {'value': 'dues', 'label': 'Aidat', 'icon': Icons.water_drop},
    {'value': 'commission', 'label': 'Komisyon', 'icon': Icons.percent},
    {'value': 'utility', 'label': 'Fatura', 'icon': Icons.bolt},
    {'value': 'other_income', 'label': 'Diğer Gelir', 'icon': Icons.attach_money},
  ];

  static const _expenseCategories = [
    {'value': 'office', 'label': 'Ofis Gideri', 'icon': Icons.business},
    {'value': 'maintenance', 'label': 'Bakım/Onarım', 'icon': Icons.build},
    {'value': 'utility', 'label': 'Fatura', 'icon': Icons.bolt},
    {'value': 'landlord', 'label': 'Ev Sahibi Ödemesi', 'icon': Icons.person},
    {'value': 'building_op', 'label': 'Bina Gideri', 'icon': Icons.apartment},
    {'value': 'other_expense', 'label': 'Diğer Gider', 'icon': Icons.money_off},
  ];

  // ─── Color palette (refined ledger) ────────────────────────────────────────
  static const _incomeColor = Color(0xFF4ADE80);
  static const _expenseColor = Color(0xFFF87171);

  static const _categoryColors = [
    Color(0xFF4ADE80),
    Color(0xFF60A5FA),
    Color(0xFFFBBF24),
    Color(0xFFA78BFA),
    Color(0xFF34D399),
    Color(0xFFF472B6),
    Color(0xFF38BDF8),
    Color(0xFFFB923C),
  ];

  // ─── Transaction source labels ──────────────────────────────────────────────
  String _txSource(dynamic tx) {
    final src = tx['source'] as String?;
    if (src == 'finance_tab') return 'Finans Ekranı';
    if (src == 'building_ops') return 'Bina Operasyonu';
    return 'Manuel';
  }

  Color _txSourceColor(dynamic tx) {
    final src = tx['source'] as String?;
    if (src == 'finance_tab') return const Color(0xFF60A5FA);
    if (src == 'building_ops') return const Color(0xFFA78BFA);
    return AppColors.textBody.withValues(alpha: 0.5);
  }

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // §5.3 — Offline kuyruk sayısını al
      final storage = OfflineStorage();
      _pendingTxCount = storage.txQueueCount;

      final dateRange = _getDateRange(_selectedPeriod);

      final responses = await Future.wait([
        ApiClient.dio.get('/finance/transactions', queryParameters: {
          if (dateRange['start'] != null) 'start_date': dateRange['start'],
          if (dateRange['end'] != null) 'end_date': dateRange['end'],
          if (_selectedCategory != null) 'category': _selectedCategory,
          'limit': 200,
        }),
        ApiClient.dio.get('/finance/monthly-stats', queryParameters: {
          'year': DateTime.now().year,
        }),
        ApiClient.dio.get('/finance/category-breakdown', queryParameters: {
          if (dateRange['start'] != null) 'start_date': dateRange['start'],
          if (dateRange['end'] != null) 'end_date': dateRange['end'],
        }),
        ApiClient.dio.get('/properties', queryParameters: {'limit': 100}),
      ]);

      final txResponse = responses[0];
      final monthlyResponse = responses[1];
      final categoryResponse = responses[2];
      final propsResponse = responses[3];

      if (txResponse.statusCode == 200) {
        _report = txResponse.data;
        _transactions = txResponse.data['transactions'] ?? [];
      }

      if (monthlyResponse.statusCode == 200) {
        _monthlyData = monthlyResponse.data['months'] ?? [];
      }

      if (categoryResponse.statusCode == 200) {
        _categoryBreakdown = categoryResponse.data['breakdown'] ?? [];
      }

      if (propsResponse.statusCode == 200) {
        _properties = propsResponse.data['properties'] ?? [];
      }

      _isLoading = false;
      _staggerController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, String?> _getDateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'this_week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return {
          'start': _formatDate(startOfWeek),
          'end': _formatDate(now),
        };
      case 'this_month':
        return {
          'start': _formatDate(DateTime(now.year, now.month, 1)),
          'end': _formatDate(now),
        };
      case 'last_month':
        return {
          'start': _formatDate(DateTime(now.year, now.month - 1, 1)),
          'end': _formatDate(DateTime(now.year, now.month, 0)),
        };
      case 'this_year':
        return {
          'start': _formatDate(DateTime(now.year, 1, 1)),
          'end': _formatDate(now),
        };
      default:
        return {'start': null, 'end': null};
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ─── Excel export ───────────────────────────────────────────────────────────
  Future<void> _exportToExcel() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Mali Rapor'];

      final periodLabel = _getPeriodLabel();
      sheet.cell(CellIndex.indexByString('A1')).value =
          TextCellValue('Emlakdefter Mali Rapor — $periodLabel');

      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Toplam Gelir: ₺${_totalIncome.toStringAsFixed(2)}  |  '
        'Toplam Gider: ₺${_totalExpense.toStringAsFixed(2)}  |  '
        'Net Bakiye: ₺${_netBalance.toStringAsFixed(2)}',
      );

      final headers = ['Tarih', 'Tür', 'Kategori', 'Mülk', 'Açıklama', 'Tutar'];
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3)).value =
            TextCellValue(headers[i]);
      }

      for (var i = 0; i < _transactions.length; i++) {
        final tx = _transactions[i];
        final rowIndex = i + 4;
        final isIncome = tx['type'] == 'income';
        final amount = (tx['amount'] ?? 0).toDouble();
        final date = tx['transaction_date'] ?? '';
        final desc = tx['description'] ?? '';
        final category = tx['category'] ?? 'other';
        final propertyName = tx['property_name'] ?? '-';

        final rowData = [
          _formatDateDisplay(date),
          isIncome ? 'Gelir' : 'Gider',
          _capitalize(category),
          propertyName,
          desc,
          '${isIncome ? '+' : '-'}₺${amount.toStringAsFixed(2)}',
        ];
        for (var j = 0; j < rowData.length; j++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex))
              .value = TextCellValue(rowData[j]);
        }
      }

      final directory = await getTemporaryDirectory();
      final fileName = 'emlakdefter_mali_rapor_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);
      await Share.shareXFiles([XFile(file.path)], subject: 'Emlakdefter Mali Rapor');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel raporu hazırlandı'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export hatası: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── Yeni işlem ekle ───────────────────────────────────────────────────────
  // §5.3 — Offline: queues to outbox if no connectivity
  Future<void> _submitNewTransaction() async {
    final amountText = _formAmountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin'), backgroundColor: AppColors.error),
      );
      return;
    }

    final category = _isCustomCategory
        ? 'other'
        : _formCategory;
    final customCategoryName = _isCustomCategory
        ? _formCustomCategoryController.text.trim()
        : null;

    final payload = <String, dynamic>{
      'type': _formType,
      'category': category,
      'amount': amount,
      'transaction_date': DateTime.now().toIso8601String().split('T')[0],
      'description': _formDescController.text.trim(),
      'source': 'manual',
    };

    if (customCategoryName != null && customCategoryName.isNotEmpty) {
      payload['custom_category'] = customCategoryName;
    }

    if (_formPropertyId != null) {
      payload['property_id'] = _formPropertyId;
    }

    final conn = ConnectivityService();
    final storage = OfflineStorage();

    // §5.3 — Offline: queue to local box
    if (!conn.isOnline) {
      final localId = const Uuid().v4();
      await storage.addToTxQueue(localId, {'local_id': localId, ...payload});
      if (mounted) {
        Navigator.pop(context);
        _formAmountController.clear();
        _formDescController.clear();
        _formCustomCategoryController.clear();
        setState(() {
          _isCustomCategory = false;
          _formPropertyId = null;
          _pendingTxCount = storage.txQueueCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem kuyruğa eklendi — bağlantı gelince senkronize edilecek'),
            backgroundColor: Color(0xFFD4A574),
          ),
        );
      }
      return;
    }

    try {
      await ApiClient.dio.post('/finance/transactions', data: payload);

      if (mounted) {
        Navigator.pop(context);
        _formAmountController.clear();
        _formDescController.clear();
        _formCustomCategoryController.clear();
        setState(() {
          _isCustomCategory = false;
          _formPropertyId = null;
        });
        await _fetchAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İşlem eklendi'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      // §5.3 fallback — queue on network error
      final localId = const Uuid().v4();
      await storage.addToTxQueue(localId, {'local_id': localId, ...payload});
      if (mounted) {
        Navigator.pop(context);
        _formAmountController.clear();
        _formDescController.clear();
        _formCustomCategoryController.clear();
        setState(() {
          _isCustomCategory = false;
          _formPropertyId = null;
          _pendingTxCount = storage.txQueueCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem kuyruğa eklendi — bağlantı gelince senkronize edilecek'),
            backgroundColor: Color(0xFFD4A574),
          ),
        );
      }
    }
  }

  void _showAddTransactionSheet(BuildContext ctx) {
    setState(() {
      _formType = 'income';
      _formCategory = 'rent';
      _isCustomCategory = false;
      _formPropertyId = null;
    });

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx2) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 28, right: 28, top: 28,
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 32,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF111118),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Yeni İşlem',
                        style: TextStyle(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold, letterSpacing: -0.5,
                        )),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx2),
                      icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Gelir / Gider toggle
                _buildTypeSelector(setSheetState),
                const SizedBox(height: 20),

                // Kategori seçimi
                const Text('Kategori', style: TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 1,
                )),
                const SizedBox(height: 10),
                _buildCategorySelector(setSheetState),
                const SizedBox(height: 16),

                // Özel kategori input
                if (_isCustomCategory) ...[
                  TextField(
                    controller: _formCustomCategoryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ör: nakliye, sigorta, temsilci ücreti',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Mülk bağlama (PRD §4.1.6-B — Bağlı Kayıt)
                const Text('Mülk Bağla (opsiyonel)', style: TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 1,
                )),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: DropdownButton<String?>(
                    value: _formPropertyId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E28),
                    underline: const SizedBox(),
                    hint: Text('Mülk seçin...',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.4)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Mülk bağlama', style: TextStyle(color: Colors.white))),
                      ..._properties.map((p) => DropdownMenuItem(
                            value: p['id'] as String,
                            child: Text(p['name'] ?? '—', style: const TextStyle(color: Colors.white)),
                          )),
                    ],
                    onChanged: (v) => setSheetState(() => _formPropertyId = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Tutar
                TextField(
                  controller: _formAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    prefixText: '₺ ',
                    prefixStyle: const TextStyle(color: Colors.white, fontSize: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Açıklama
                TextField(
                  controller: _formDescController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Açıklama (opsiyonel)',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 28),

                // Kaydet butonu
                GestureDetector(
                  onTap: _submitNewTransaction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0.9),
                          AppColors.accent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('Kaydet',
                          style: TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.bold, letterSpacing: 0.5,
                          )),
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

  Widget _buildTypeSelector(void Function(void Function()) setSheetState) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(child: _typeButton('income', 'Gelir', _incomeColor, setSheetState)),
          Expanded(child: _typeButton('expense', 'Gider', _expenseColor, setSheetState)),
        ],
      ),
    );
  }

  Widget _typeButton(String type, String label, Color color,
      void Function(void Function()) setSheetState) {
    final isSelected = _formType == type;
    return GestureDetector(
      onTap: () => setSheetState(() {
        _formType = type;
        _formCategory = type == 'income' ? 'rent' : 'office';
        _isCustomCategory = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(isSelected ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color, size: 16),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white.withValues(alpha: 0.4),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(void Function(void Function()) setSheetState) {
    final categories =
        _formType == 'income' ? _incomeCategories : _expenseCategories;
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        ...categories.map((cat) => _categoryChip(cat, setSheetState)),
        _customCategoryChip(setSheetState),
      ],
    );
  }

  Widget _categoryChip(Map<String, dynamic> cat,
      void Function(void Function()) setSheetState) {
    final isSelected = !_isCustomCategory && _formCategory == cat['value'];
    final color = _formType == 'income' ? _incomeColor : _expenseColor;
    return GestureDetector(
      onTap: () => setSheetState(() {
        _formCategory = cat['value'];
        _isCustomCategory = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat['icon'], size: 15,
                color: isSelected ? color : Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 7),
            Text(cat['label'],
                style: TextStyle(
                  color: isSelected ? color : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _customCategoryChip(void Function(void Function()) setSheetState) {
    final color = _formType == 'income' ? _incomeColor : _expenseColor;
    return GestureDetector(
      onTap: () => setSheetState(() => _isCustomCategory = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _isCustomCategory
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isCustomCategory
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15,
                color: _isCustomCategory ? color : Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 7),
            Text('Yeni Kategori',
                style: TextStyle(
                  color: _isCustomCategory ? color : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: _isCustomCategory ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  // ─── Computed ──────────────────────────────────────────────────────────────
  double get _totalIncome => (_report?['total_income'] ?? 0).toDouble();
  double get _totalExpense => (_report?['total_expense'] ?? 0).toDouble();
  double get _netBalance => _totalIncome - _totalExpense;
  int get _incomeCount =>
      _transactions.where((t) => t['type'] == 'income').length;
  int get _expenseCount =>
      _transactions.where((t) => t['type'] == 'expense').length;

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _buildErrorState()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 8),
                          _buildPeriodSelector(),
                          const SizedBox(height: 16),
                          _buildSummaryCards(),
                          const SizedBox(height: 24),
                          _buildChartSection(),
                          const SizedBox(height: 24),
                          _buildCategoryFilter(),
                          const SizedBox(height: 24),
                          _buildTransactionList(),
                          const SizedBox(height: 120),
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0D0D14),
      foregroundColor: Colors.white,
      pinned: true,
      expandedHeight: 96,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mali Rapor',
                style: TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold, letterSpacing: -0.3,
                )),
            Text(_getPeriodLabel(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 11,
                )),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _fetchAllData,
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.refresh, size: 20),
          ),
        ),
        IconButton(
          onPressed: _transactions.isEmpty ? null : _exportToExcel,
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.download_rounded, size: 20, color: _incomeColor),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _showAddTransactionSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withValues(alpha: 0.85), AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('İşlem',
                    style: TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'this_week': return 'Bu Hafta';
      case 'this_month': return 'Bu Ay';
      case 'last_month': return 'Geçen Ay';
      case 'this_year': return 'Bu Yıl';
      default: return 'Bu Ay';
    }
  }

  // ─── Period Selector ───────────────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    final periods = [
      ('this_week', 'Hafta'),
      ('this_month', 'Ay'),
      ('last_month', 'Geçen Ay'),
      ('this_year', 'Yıl'),
    ];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(offset: Offset(0, 12 * (1 - anim)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: periods.map((p) {
            final isSelected = _selectedPeriod == p.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPeriod = p.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(p.$2, textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Özet Kartları (Staggered) ────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _staggerCard(0, _buildIncomeCard())),
            const SizedBox(width: 12),
            Expanded(child: _staggerCard(1, _buildExpenseCard())),
          ],
        ),
        const SizedBox(height: 12),
        _staggerCard(2, _buildNetBalanceCard()),
      ],
    );
  }

  Widget _staggerCard(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 100),
      curve: Curves.easeOutCubic,
      builder: (context, anim, _) => Opacity(
        opacity: anim,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - anim)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _incomeColor.withValues(alpha: 0.15),
            _incomeColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _incomeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _incomeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up_rounded, color: _incomeColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _incomeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_incomeCount işlem',
                    style: const TextStyle(color: _incomeColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Toplam Gelir',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('₺${_formatNumber(_totalIncome)}',
                style: const TextStyle(
                  color: _incomeColor, fontSize: 24,
                  fontWeight: FontWeight.bold, letterSpacing: -0.8,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _expenseColor.withValues(alpha: 0.15),
            _expenseColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _expenseColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _expenseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_down_rounded, color: _expenseColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _expenseColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_expenseCount işlem',
                    style: const TextStyle(color: _expenseColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Toplam Gider',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('₺${_formatNumber(_totalExpense)}',
                style: const TextStyle(
                  color: _expenseColor, fontSize: 24,
                  fontWeight: FontWeight.bold, letterSpacing: -0.8,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildNetBalanceCard() {
    final isPositive = _netBalance >= 0;
    final color = isPositive ? _incomeColor : _expenseColor;
    final ratio = _totalExpense > 0 ? (_totalIncome / _totalExpense) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.12),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.12),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
              color: Colors.white, size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NET BAKİYE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    )),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _netBalance),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => Text(
                    '${isPositive ? '+' : ''}₺${_formatNumber(val)}',
                    style: TextStyle(
                      color: color, fontSize: 30,
                      fontWeight: FontWeight.bold, letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ratio > 0 ? '${ratio.toStringAsFixed(1)}x' : '—',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 5),
              Text('Gel/Gid Oranı',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Grafikler ─────────────────────────────────────────────────────────────
  Widget _buildChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _staggerLabel(3, 'KATEGORİ DAĞILIMI'),
        const SizedBox(height: 14),
        Container(
          height: 270,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: _categoryBreakdown.isEmpty
              ? _buildEmptyChart()
              : Row(
                  children: [
                    Expanded(child: _buildCategoryPieChart()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCategoryLegend()),
                  ],
                ),
        ),
        const SizedBox(height: 28),
        _staggerLabel(4, 'AYLIK TREND'),
        const SizedBox(height: 14),
        Container(
          height: 220,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: _monthlyData.isEmpty ? _buildEmptyChart() : _buildBarChart(),
        ),
      ],
    );
  }

  Widget _staggerLabel(int index, String text) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, anim, _) => Opacity(
        opacity: anim,
        child: Transform.translate(
          offset: Offset(-12 * (1 - anim), 0),
          child: Text(text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              )),
        ),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline,
              size: 52, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 14),
          Text('Henüz veri yok',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    final total = _categoryBreakdown.fold<double>(
        0, (sum, b) => sum + (b['total'] ?? 0).toDouble());
    if (total == 0) return _buildEmptyChart();

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.touchedSection == null) {
                _touchedCategoryIndex = -1;
                return;
              }
              _touchedCategoryIndex =
                  response.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 48,
        sections: List.generate(_categoryBreakdown.length, (i) {
          final item = _categoryBreakdown[i];
          final value = (item['total'] ?? 0).toDouble();
          final pct = value / total * 100;
          final isTouched = _touchedCategoryIndex == i;
          return PieChartSectionData(
            value: value,
            color: _categoryColors[i % _categoryColors.length],
            radius: isTouched ? 68 : 58,
            title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
            titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCategoryLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        _categoryBreakdown.length.clamp(0, 6),
        (i) {
          final item = _categoryBreakdown[i];
          final color = _categoryColors[i % _categoryColors.length];
          final total = _categoryBreakdown.fold<double>(
              0, (sum, b) => sum + (b['total'] ?? 0).toDouble());
          final pct = total > 0
              ? ((item['total'] ?? 0).toDouble() / total * 100).toStringAsFixed(1)
              : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_capitalize(item['category'] ?? ''),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65), fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '₺${_formatNumber((item['total'] ?? 0).toDouble())}',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text('($pct%)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35), fontSize: 10,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBarChart() {
    if (_monthlyData.isEmpty) return _buildEmptyChart();

    final maxVal = _monthlyData.fold<double>(0, (max, m) {
      final income = (m['income'] ?? 0).toDouble();
      final expense = (m['expense'] ?? 0).toDouble();
      return [max, income, expense].reduce((a, b) => a > b ? a : b);
    });

    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.04),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 44, interval: maxVal > 0 ? maxVal / 4 : 20,
              getTitlesWidget: (value, _) => Text(
                '₺${_formatNumber(value)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _monthlyData.length) return const SizedBox();
                final monthName = (_monthlyData[idx]['month_name'] ?? '') as String;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthName.length > 3 ? monthName.substring(0, 3) : monthName,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(_monthlyData.length, (i) {
          final income = (_monthlyData[i]['income'] ?? 0).toDouble();
          final expense = (_monthlyData[i]['expense'] ?? 0).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: income, color: _incomeColor, width: 7,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: expense, color: _expenseColor.withValues(alpha: 0.75), width: 7,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─── Kategori Filtresi ────────────────────────────────────────────────────
  Widget _buildCategoryFilter() {
    final categories = [
      {'value': '', 'label': 'Tümü', 'icon': Icons.layers},
      {'value': 'rent', 'label': 'Kira', 'icon': Icons.home},
      {'value': 'dues', 'label': 'Aidat', 'icon': Icons.water_drop},
      {'value': 'commission', 'label': 'Komisyon', 'icon': Icons.percent},
      {'value': 'office', 'label': 'Ofis', 'icon': Icons.business},
      {'value': 'landlord', 'label': 'Ev Sahibi', 'icon': Icons.person},
      {'value': 'building_op', 'label': 'Bina', 'icon': Icons.apartment},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _staggerLabel(5, 'KATEGORİ FİLTRELE'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['value'] as String?),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat['icon'] as IconData, size: 14,
                            color: isSelected
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.35)),
                        const SizedBox(width: 7),
                        Text((cat['label'] ?? '').toString(),
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.white.withValues(alpha: 0.45),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── İşlem Listesi ─────────────────────────────────────────────────────────
  Widget _buildTransactionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _staggerLabel(6, 'İŞLEMLER'),
            Row(
              children: [
                // §5.3 — Offline kuyruk badge
                if (_pendingTxCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A574).withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 10, color: Color(0xFFD4A574)),
                        const SizedBox(width: 3),
                        Text(
                          '$_pendingTxCount kuyrukta',
                          style: const TextStyle(
                            color: Color(0xFFD4A574), fontSize: 10, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_transactions.length} kayıt',
                    style: const TextStyle(
                      color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 52, color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 16),
                  Text('Henüz işlem kaydı yok',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.25))),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddTransactionSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('İlk işlemi ekle'),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(
            _transactions.length,
            (i) => _staggerTransactionItem(i, _transactions[i]),
          ),
      ],
    );
  }

  Widget _staggerTransactionItem(int index, dynamic tx) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 40).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - anim)),
          child: child,
        ),
      ),
      child: _buildTransactionItem(tx),
    );
  }

  Widget _buildTransactionItem(dynamic tx) {
    final isIncome = tx['type'] == 'income';
    final color = isIncome ? _incomeColor : _expenseColor;
    final amount = (tx['amount'] ?? 0).toDouble();
    final desc = tx['description'] ?? '';
    final category = (tx['category'] ?? 'other').toString();
    final propertyName = tx['property_name'] as String?;
    final source = _txSource(tx);
    final sourceColor = _txSourceColor(tx);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_getCategoryIcon(category), color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_capitalize(category),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 3),
                    Text(
                      desc.isNotEmpty
                          ? (desc.length > 48 ? '${desc.substring(0, 48)}...' : desc)
                          : '—',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35), fontSize: 11,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}₺${_formatNumber(amount)}',
                    style: TextStyle(
                      color: color, fontSize: 16, fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(_formatDateDisplay(tx['transaction_date'] ?? ''),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3), fontSize: 10,
                      )),
                ],
              ),
            ],
          ),
          // Kaynak + Mülk etiketleri (PRD §4.1.6-C)
          if (propertyName != null || source != 'Manuel') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (source != 'Manuel') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(source,
                        style: TextStyle(
                          color: sourceColor, fontSize: 9,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  const SizedBox(width: 6),
                ],
                if (propertyName != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.apartment,
                              size: 10, color: Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(propertyName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 9,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'rent': return Icons.home_outlined;
      case 'dues': return Icons.water_drop;
      case 'commission': return Icons.percent;
      case 'maintenance': return Icons.build_outlined;
      case 'utility': return Icons.bolt_outlined;
      case 'office': return Icons.business;
      case 'landlord': return Icons.person;
      case 'building_op': return Icons.apartment;
      default: return Icons.attach_money_rounded;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }

  String _formatDateDisplay(String date) {
    if (date.isEmpty) return '-';
    try {
      final parts = date.split('T')[0].split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    } catch (_) {}
    return date;
  }

  String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: _expenseColor.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          const Text('Veri yüklenemedi',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          TextButton(onPressed: _fetchAllData, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _formAmountController.dispose();
    _formDescController.dispose();
    _formCustomCategoryController.dispose();
    super.dispose();
  }
}
