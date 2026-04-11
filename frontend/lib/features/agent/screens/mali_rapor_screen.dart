import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';

/// Mali Rapor Ekranı — PRD §4.1.6
/// Özet kartlar, pasta grafik, bar grafik, işlem listesi
class MaliRaporScreen extends ConsumerStatefulWidget {
  const MaliRaporScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MaliRaporScreen> createState() => _MaliRaporScreenState();
}

class _MaliRaporScreenState extends ConsumerState<MaliRaporScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _report;
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = 'this_month';
  int _touchedPieIndex = -1;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Yeni işlem formu
  final _formAmountController = TextEditingController();
  final _formDescController = TextEditingController();
  String _formType = 'income';
  String _formCategory = 'rent';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.dio.get('/finance/transactions');
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _report = response.data;
          _transactions = response.data['transactions'] ?? [];
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Mali Rapor'];

      // Title row
      final periodLabel = _getPeriodLabel();
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('Emlakdefter Mali Rapor — $periodLabel');

      // Summary row
      final summaryCell = sheet.cell(CellIndex.indexByString('A2'));
      summaryCell.value = TextCellValue(
        'Toplam Gelir: ₺${_totalIncome.toStringAsFixed(2)}  |  Toplam Gider: ₺${_totalExpense.toStringAsFixed(2)}  |  Net Bakiye: ₺${_netBalance.toStringAsFixed(2)}',
      );

      // Header row
      final headers = ['Tarih', 'Tür', 'Kategori', 'Açıklama', 'Tutar'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
        cell.value = TextCellValue(headers[i]);
      }

      // Data rows
      for (var i = 0; i < _transactions.length; i++) {
        final tx = _transactions[i];
        final rowIndex = i + 4;
        final isIncome = tx['type'] == 'income';
        final amount = (tx['amount'] ?? 0).toDouble();
        final date = tx['transaction_date'] ?? '';
        final desc = tx['description'] ?? '';
        final category = tx['category'] ?? 'other';

        final formattedDate = _formatDate(date);
        final typeLabel = isIncome ? 'Gelir' : 'Gider';
        final categoryLabel = _capitalize(category);
        final amountStr = '${isIncome ? '+' : '-'}₺${amount.toStringAsFixed(2)}';

        final rowData = [formattedDate, typeLabel, categoryLabel, desc, amountStr];
        for (var j = 0; j < rowData.length; j++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
          cell.value = TextCellValue(rowData[j]);
        }
      }


      final directory = await getTemporaryDirectory();
      final fileName = 'emlakdefter_mali_rapor_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Emlakdefter Mali Rapor — $periodLabel',
        text: 'Mali Raporunuz: $periodLabel dönemine aittir.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel raporu hazırlandı!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel export hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitNewTransaction() async {
    final amountText = _formAmountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin'), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final resp = await ApiClient.dio.post('/finance/transactions', data: {
        'type': _formType,
        'category': _formCategory,
        'amount': amount,
        'transaction_date': today,
        'description': _formDescController.text.trim(),
      });

      if (resp.statusCode == 201) {
        Navigator.pop(context);
        _formAmountController.clear();
        _formDescController.clear();
        await _fetchReport();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem eklendi!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showAddTransactionSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx2) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Yeni İşlem Ekle', style: TextStyle(
                  color: AppColors.textHeader, fontSize: 20, fontWeight: FontWeight.bold,
                )),
                IconButton(
                  onPressed: () => Navigator.pop(ctx2),
                  icon: const Icon(Icons.close, color: AppColors.textBody),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Gelir / Gider seçimi
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _formType = 'income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _formType == 'income' ? AppColors.success.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('Gelir', style: TextStyle(
                            color: _formType == 'income' ? AppColors.success : AppColors.textBody,
                            fontWeight: FontWeight.bold,
                          )),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _formType = 'expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _formType == 'expense' ? AppColors.error.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('Gider', style: TextStyle(
                            color: _formType == 'expense' ? AppColors.error : AppColors.textBody,
                            fontWeight: FontWeight.bold,
                          )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kategori seçimi
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _catChip('rent', 'Kira', Icons.home),
                _catChip('dues', 'Aidat', Icons.water_drop),
                _catChip('commission', 'Komisyon', Icons.percent),
                _catChip('maintenance', 'Bakım', Icons.build),
                _catChip('utility', 'Fatura', Icons.electrical_services),
                _catChip('other', 'Diğer', Icons.more_horiz),
              ].map((chip) {
                final isSelected = _formCategory == chip[1];
                return GestureDetector(
                  onTap: () => setState(() => _formCategory = chip[1]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(chip[2], size: 16, color: isSelected ? AppColors.accent : AppColors.textBody),
                        const SizedBox(width: 6),
                        Text(chip[0], style: TextStyle(color: isSelected ? AppColors.accent : AppColors.textBody, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Tutar
            TextField(
              controller: _formAmountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Tutar (₺)',
                labelStyle: TextStyle(color: AppColors.textBody.withValues(alpha: 0.6)),
                prefixText: '₺ ',
                prefixStyle: const TextStyle(color: AppColors.textHeader, fontSize: 18),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Açıklama
            TextField(
              controller: _formDescController,
              style: const TextStyle(color: AppColors.textHeader),
              decoration: InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                labelStyle: TextStyle(color: AppColors.textBody.withValues(alpha: 0.6)),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Gönder
            ElevatedButton(
              onPressed: _submitNewTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  dynamic _catChip(String val, String lbl, IconData ic) => [lbl, val, ic];

  double get _totalIncome => (_report?['total_income'] ?? 0).toDouble();
  double get _totalExpense => (_report?['total_expense'] ?? 0).toDouble();
  double get _netBalance => (_report?['net_balance'] ?? 0).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _buildErrorState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  _buildPeriodSelector(),
                  const SizedBox(height: 20),
                  FadeTransition(opacity: _fadeAnimation, child: _buildSummaryCards()),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildChartSection(),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildTransactionList(),
                  ),
                  const SizedBox(height: 120),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textHeader,
      pinned: true,
      expandedHeight: 100,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mali Rapor',
              style: TextStyle(
                color: AppColors.textHeader,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getPeriodLabel(),
              style: TextStyle(
                color: AppColors.textBody,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.refresh, size: 20),
          ),
          onPressed: _fetchReport,
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.download_rounded, size: 20, color: AppColors.success),
          ),
          onPressed: _transactions.isEmpty ? null : _exportToExcel,
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _showAddTransactionSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.8), AppColors.accent]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text('Yeni İşlem', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'this_week':
        return 'Bu Hafta';
      case 'this_month':
        return 'Bu Ay';
      case 'last_month':
        return 'Geçen Ay';
      case 'this_year':
        return 'Bu Yıl';
      default:
        return 'Bu Ay';
    }
  }

  Widget _buildPeriodSelector() {
    final periods = [
      ('this_week', 'Hafta'),
      ('this_month', 'Ay'),
      ('last_month', 'Geçen Ay'),
      ('this_year', 'Yıl'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textBody,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard(
              'Toplam Gelir',
              '₺${_formatNumber(_totalIncome)}',
              Icons.trending_up_rounded,
              AppColors.success,
              'arrow_upward',
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard(
              'Toplam Gider',
              '₺${_formatNumber(_totalExpense)}',
              Icons.trending_down_rounded,
              AppColors.error,
              'arrow_downward',
            )),
          ],
        ),
        const SizedBox(height: 12),
        _buildNetBalanceCard(),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, String arrow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
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
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 14),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(color: AppColors.textBody, fontSize: 12),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetBalanceCard() {
    final isPositive = _netBalance >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.2),
            color.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.3),
                  color.withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
              color: AppColors.textHeader,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net Bakiye',
                  style: TextStyle(color: AppColors.textBody, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isPositive ? '+' : ''}₺${_formatNumber(_netBalance)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${((_totalIncome / (_totalExpense == 0 ? 1 : _totalExpense)) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gelir/Oran',
                style: TextStyle(color: AppColors.textBody, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Gelir-Gider Dağılımı'),
        const SizedBox(height: 16),
        Container(
          height: 260,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: _totalIncome == 0 && _totalExpense == 0
              ? _buildEmptyChart()
              : Row(
                  children: [
                    Expanded(child: _buildPieChart()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildPieLegend()),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Aylık Trend'),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: _buildBarChart(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textHeader,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 48, color: AppColors.textBody.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            'Henüz veri yok',
            style: TextStyle(color: AppColors.textBody, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.touchedSection == null) {
                _touchedPieIndex = -1;
                return;
              }
              _touchedPieIndex = response.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 3,
        centerSpaceRadius: 45,
        sections: [
          PieChartSectionData(
            value: _totalIncome,
            color: AppColors.success,
            radius: _touchedPieIndex == 0 ? 60 : 50,
            title: _touchedPieIndex == 0
                ? '${((_totalIncome / (_totalIncome + _totalExpense == 0 ? 1 : _totalIncome + _totalExpense)) * 100).toStringAsFixed(0)}%'
                : '',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          PieChartSectionData(
            value: _totalExpense,
            color: AppColors.error,
            radius: _touchedPieIndex == 1 ? 60 : 50,
            title: _touchedPieIndex == 1
                ? '${((_totalExpense / (_totalIncome + _totalExpense == 0 ? 1 : _totalIncome + _totalExpense)) * 100).toStringAsFixed(0)}%'
                : '',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendItem('Gelir', _totalIncome, AppColors.success),
        const SizedBox(height: 20),
        _buildLegendItem('Gider', _totalExpense, AppColors.error),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Net Marj',
                  style: TextStyle(color: AppColors.textBody, fontSize: 12),
                ),
              ),
              Text(
                '${(_netBalance >= 0 ? '+' : '')}${(_netBalance / (_totalIncome == 0 ? 1 : _totalIncome) * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _netBalance >= 0 ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(color: AppColors.textBody, fontSize: 13)),
        ),
        Text(
          '₺${_formatNumber(value)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final months = ['O', 'Ş', 'M', 'N', 'M', 'H', 'T', 'A', 'E', 'E', 'K', 'A'];
    // Simulated monthly data — in production, this would come from the API
    final incomeData = [45, 52, 38, 60, 55, 48, 65, 70, 58, 72, 68, 80];
    final expenseData = [20, 25, 30, 22, 35, 28, 30, 32, 40, 35, 38, 30];

    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 20,
              getTitlesWidget: (value, meta) => Text(
                '₺${value.toInt()}K',
                style: TextStyle(color: AppColors.textBody, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    months[idx],
                    style: TextStyle(color: AppColors.textBody, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(12, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: incomeData[i].toDouble(),
                color: AppColors.success,
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: expenseData[i].toDouble(),
                color: AppColors.error.withOpacity(0.7),
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTransactionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Son İşlemler'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_transactions.length} işlem',
                style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textBody.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz işlem kaydı yok',
                    style: TextStyle(color: AppColors.textBody),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(_transactions.length, (i) {
            final tx = _transactions[i];
            return _buildTransactionItem(tx, i);
          }),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, int index) {
    final isIncome = tx['type'] == 'income';
    final color = isIncome ? AppColors.success : AppColors.error;
    final amount = (tx['amount'] ?? 0).toDouble();
    final date = tx['transaction_date'] ?? '';
    final desc = tx['description'] ?? '';
    final category = tx['category'] ?? 'other';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalize(category),
                  style: TextStyle(
                    color: AppColors.textHeader,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc.length > 40 ? '${desc.substring(0, 40)}...' : desc,
                  style: TextStyle(color: AppColors.textBody, fontSize: 11),
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
                '${isIncome ? '+' : '-'}₺${_formatNumber(amount)}',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatDate(date),
                style: TextStyle(color: AppColors.textBody, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'rent':
        return Icons.home_outlined;
      case 'dues':
        return Icons.receipt_outlined;
      case 'commission':
        return Icons.percent;
      case 'maintenance':
        return Icons.build_outlined;
      case 'utility':
        return Icons.bolt_outlined;
      default:
        return Icons.attach_money_rounded;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '-';
    try {
      final parts = date.split('T')[0].split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return date;
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Veri yüklenemedi',
            style: TextStyle(color: AppColors.textHeader, fontSize: 18),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _fetchReport,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}
