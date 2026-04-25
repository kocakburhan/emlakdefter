import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'dart:io' show File;
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import 'bi_analytics_screen_web_stub.dart'
    if (dart.library.js_interop) 'bi_analytics_screen_web.dart';

// ──────────────────────────────────────────────
// PROVIDER
// ──────────────────────────────────────────────

class BIAnalyticsData {
  final Map<String, dynamic>? portfolio;
  final Map<String, dynamic>? tenantChurn;
  final Map<String, dynamic>? financial;
  final Map<String, dynamic>? collection;
  final bool isLoading;
  final String? error;
  final bool isForbidden; // §4.1.10 — Admin-only erişim

  BIAnalyticsData({
    this.portfolio,
    this.tenantChurn,
    this.financial,
    this.collection,
    this.isLoading = false,
    this.error,
    this.isForbidden = false,
  });

  factory BIAnalyticsData.fromJson(Map<String, dynamic> json) {
    return BIAnalyticsData(
      portfolio: json['portfolio'],
      tenantChurn: json['tenant_churn'],
      financial: json['financial'],
      collection: json['collection'],
    );
  }
}

class BIAnalyticsNotifier extends StateNotifier<AsyncValue<BIAnalyticsData>> {
  BIAnalyticsNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.dio.get('/analytics/bi-dashboard');
      if (resp.statusCode == 200 && resp.data != null) {
        state = AsyncValue.data(BIAnalyticsData.fromJson(resp.data));
      } else {
        state = AsyncValue.data(BIAnalyticsData());
      }
    } catch (e) {
      // §4.1.10: 403 Forbidden → Admin değil
      if (e.toString().contains('403')) {
        state = AsyncValue.data(BIAnalyticsData(isForbidden: true));
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> refresh() => fetch();
}

final biAnalyticsProvider = StateNotifierProvider<BIAnalyticsNotifier, AsyncValue<BIAnalyticsData>>((ref) {
  return BIAnalyticsNotifier();
});

// ──────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────

class BIAnalyticsScreen extends ConsumerStatefulWidget {
  const BIAnalyticsScreen({super.key});

  @override
  ConsumerState<BIAnalyticsScreen> createState() => _BIAnalyticsScreenState();
}

class _BIAnalyticsScreenState extends ConsumerState<BIAnalyticsScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnim;
  String _selectedPeriod = 'Bu Yıl';
  bool _headerDone = false;

  static const _periodOptions = ['Bu Ay', 'Son 3 Ay', 'Son 6 Ay', 'Bu Yıl', 'Geçen Yıl'];

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  void _triggerExport(String type) async {
    final state = ref.read(biAnalyticsProvider);
    final data = state.value;
    if (data == null) return;

    if (type == 'pdf') {
      await _exportPdf(data);
    } else {
      await _exportExcel(data);
    }
  }

  Future<void> _exportPdf(BIAnalyticsData data) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(level: 0, child: pw.Text('Emlakdefter BI Raporu', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 8),
            pw.Text('Tarih: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            if (data.portfolio != null) ...[
              pw.Header(level: 1, child: pw.Text('A. Portföy Performansı')),
              pw.Text('Doluluk: ${data.portfolio!['overall_occupancy_rate']}%  |  Mülk: ${data.portfolio!['total_properties']}  |  Daire: ${data.portfolio!['total_units']}'),
              pw.SizedBox(height: 12),
            ],
            if (data.financial != null) ...[
              pw.Header(level: 1, child: pw.Text('C. Finansal Rapor')),
              pw.Text('Cari Yıl Gelir: ₺${data.financial!['current_year_income']}'),
              pw.Text('Cari Yıl Gider: ₺${data.financial!['current_year_expense']}'),
              pw.Text('Net Bakiye: ₺${data.financial!['current_year_net']}'),
              pw.Text('Gelir Büyüme: ${data.financial!['income_growth_percent']}%'),
            ],
          ],
        ),
      );
      final pdfBytes = await pdf.save();
      final fileName = 'emlakdefter_bi_report.pdf';

      if (kIsWeb) {
        triggerWebDownload(pdfBytes, fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Emlakdefter BI Raporu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportExcel(BIAnalyticsData data) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['BI Raporu'];

      // Header
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Emlakdefter BI Raporu — ${DateTime.now().toString().substring(0, 10)}');

      // Portfolio
      if (data.portfolio != null) {
        sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('A. Portföy Performansı');
        sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Doluluk');
        sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue('${data.portfolio!['overall_occupancy_rate']}%');
        sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Toplam Mülk');
        sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue('${data.portfolio!['total_properties']}');
      }

      // Financial
      if (data.financial != null) {
        sheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('C. Finansal Rapor');
        sheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('Cari Yıl Gelir');
        sheet.cell(CellIndex.indexByString('B8')).value = TextCellValue('${data.financial!['current_year_income']}');
        sheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('Cari Yıl Gider');
        sheet.cell(CellIndex.indexByString('B9')).value = TextCellValue('${data.financial!['current_year_expense']}');
        sheet.cell(CellIndex.indexByString('A10')).value = TextCellValue('Net Bakiye');
        sheet.cell(CellIndex.indexByString('B10')).value = TextCellValue('${data.financial!['current_year_net']}');
      }

      final bytes = excel.encode()!;
      final fileName = 'emlakdefter_bi_report.xlsx';

      if (kIsWeb) {
        triggerExcelWebDownload(bytes, fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Emlakdefter BI Raporu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel oluşturulamadı: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Color(0xFF00D9FF), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'İş Zekası Paneli',
                    style: TextStyle(
                      color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Bu panel, emlak ofisi yöneticisinin (Kurucu Emlakçı / Admin) portföyünün genel sağlık durumunu stratejik düzeyde analiz etmesini sağlar.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bölümler:', style: TextStyle(color: Color(0xFF00D9FF), fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _infoRow('A', 'Portföy Performansı', 'Doluluk oranı, boş daire yaşlandırma ve mülk bazlı analizler.'),
            _infoRow('B', 'Kiracı Sirkülasyonu', 'Aylık giriş/çıkış raporu ve kiracı sadakat analizi.'),
            _infoRow('C', 'Yıllık Finansal Rapor', 'Gelir/gider karşılaştırması, kategori trendleri ve net kar marjı.'),
            _infoRow('D', 'Tahsilat Performansı', 'Tahsilat oranı, gecikme analizi ve bekleyen alacak takibi.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFFFB800), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bu panele yalnızca Kurucu Emlakçı (Admin) erişebilir. Danışman/Çalışan rolündeki kullanıcılar bu ekranı göremez.',
                      style: TextStyle(color: Color(0xFFFFB800), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String code, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '§4.1.10-$code',
              style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(biAnalyticsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF090910),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: state.when(
                loading: () => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48, height: 48,
                        child: CircularProgressIndicator(
                          color: AppColors.charcoal,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Analiz verileri yükleniyor...',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Hata: $e', style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      TextButton(
                        onPressed: () => ref.read(biAnalyticsProvider.notifier).refresh(),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
                data: (data) {
                  // §4.1.10: Admin değil — erişim yok
                  if (data.isForbidden) {
                    return _buildForbiddenState();
                  }
                  if (data.portfolio == null && data.tenantChurn == null) {
                    return _buildEmptyState();
                  }
                  if (!_headerDone) {
                    _headerDone = true;
                    Future.microtask(() => _headerAnim.forward());
                  }
                  return _buildContent(data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF090910),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: Back + Başlık + Export + Info
          Row(
            children: [
              // Back button
              FadeTransition(
                opacity: CurvedAnimation(parent: _headerAnim, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeTransition(
                      opacity: CurvedAnimation(parent: _headerAnim, curve: const Interval(0.05, 0.55, curve: Curves.easeOut)),
                      child: const Text(
                        'ANALYTICS',
                        style: TextStyle(
                          color: Color(0xFF00D9FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FadeTransition(
                      opacity: CurvedAnimation(parent: _headerAnim, curve: const Interval(0.1, 0.6, curve: Curves.easeOut)),
                      child: const Text(
                        'İş Zekası Paneli',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info button
              FadeTransition(
                opacity: CurvedAnimation(parent: _headerAnim, curve: const Interval(0.2, 0.7, curve: Curves.easeOut)),
                child: GestureDetector(
                  onTap: _showInfoSheet,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Color(0xFF00D9FF), size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Export butonları
              FadeTransition(
                opacity: CurvedAnimation(parent: _headerAnim, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
                child: Row(
                  children: [
                    _exportBtn(Icons.picture_as_pdf_rounded, 'PDF', const Color(0xFFFF6B6B), () => _triggerExport('pdf')),
                    const SizedBox(width: 8),
                    _exportBtn(Icons.grid_on_rounded, 'Excel', AppColors.success, () => _triggerExport('excel')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dönem seçici
          FadeTransition(
            opacity: CurvedAnimation(parent: _headerAnim, curve: const Interval(0.2, 0.8, curve: Curves.easeOut)),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _periodOptions.map((p) {
                  final isSelected = _selectedPeriod == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00D9FF).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00D9FF).withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF00D9FF)
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForbiddenState() {
    // §4.1.10: Sadece Admin erişebilir
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, anim, child) => Opacity(
          opacity: anim,
          child: Transform.scale(scale: 0.85 + 0.15 * anim, child: child),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                size: 52,
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Yetkisiz Erişim',
              style: TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İş Zekası Paneli yalnızca\nKurucu Emlakçı (Admin) erişimindedir.\nDanışman/Çalışan rolündeki\nkullanıcılar bu ekranı göremez.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, anim, child) => Opacity(
          opacity: anim,
          child: Transform.scale(scale: 0.85 + 0.15 * anim, child: child),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 52,
                color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Henüz analiz verisi yok',
              style: TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finansal işlem ve kiracı verileri\ngirildikçe burası dolacak.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BIAnalyticsData data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionBadge('A', 'PORTFÖY PERFORMANSI', const Color(0xFF00D9FF)),
          const SizedBox(height: 12),
          _buildPortfolioSection(data.portfolio),
          const SizedBox(height: 32),

          _sectionBadge('B', 'KİRACI SİRKÜLASYONU', const Color(0xFFA78BFA)),
          const SizedBox(height: 12),
          _buildTenantChurnSection(data.tenantChurn),
          const SizedBox(height: 32),

          _sectionBadge('C', 'YILLIK FİNANSAL RAPOR', const Color(0xFFFFB800)),
          const SizedBox(height: 12),
          _buildFinancialSection(data.financial),
          const SizedBox(height: 32),

          _sectionBadge('D', 'TAHSİLAT PERFORMANSI', const Color(0xFF34D399)),
          const SizedBox(height: 12),
          _buildCollectionSection(data.collection),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Section Badge ─────────────────────────────────────────────────────────
  Widget _sectionBadge(String code, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            '§4.1.10-$code',
            style: TextStyle(
              color: color, fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // A. PORTFÖY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPortfolioSection(Map<String, dynamic>? p) {
    if (p == null) return _emptyStateCard('Portföy verisi yok');

    final rate = (p['overall_occupancy_rate'] as num?)?.toDouble() ?? 0.0;
    final trend = (p['occupancy_trend'] as List<dynamic>? ?? []);
    final byProp = (p['by_property'] as List<dynamic>? ?? []);

    return Column(
      children: [
        // Üst satır: Donut + KPI'lar
        _glassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Donut
              SizedBox(
                width: 130, height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 46,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            value: rate,
                            color: const Color(0xFF00D9FF),
                            radius: 14,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: (100 - rate).clamp(0.0, 100.0),
                            color: Colors.white.withValues(alpha: 0.06),
                            radius: 14,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${rate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Doluluk',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _miniKpi('Toplam Mülk', '${p['total_properties'] ?? 0}', const Color(0xFF00D9FF), Icons.home_rounded),
                    const SizedBox(height: 10),
                    _miniKpi('Toplam Daire', '${p['total_units'] ?? 0}', Colors.white.withValues(alpha: 0.7), Icons.door_front_door_outlined),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _miniKpi('Doluluk', '${p['occupied_units'] ?? 0}', AppColors.success, Icons.check_circle_outline)),
                        const SizedBox(width: 10),
                        Expanded(child: _miniKpi('Boş', '${p['vacant_units'] ?? 0}', AppColors.error, Icons.cancel_outlined)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Doluluk Trendi — Çizgi Grafik (§A-2)
        if (trend.isNotEmpty)
          _glassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, size: 16, color: const Color(0xFF00D9FF).withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    const Text(
                      'Doluluk Trendi (12 Ay)',
                      style: TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: Colors.white.withValues(alpha: 0.04),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            interval: 2,
                            getTitlesWidget: (val, _) {
                              if (val.toInt() >= trend.length) return const SizedBox();
                              return Text(
                                trend[val.toInt()]['month'].toString().substring(5),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 9,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 25,
                            getTitlesWidget: (val, _) => Text(
                              '${val.toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            trend.length,
                            (i) => FlSpot(i.toDouble(), (trend[i]['occupancy_rate'] ?? 0).toDouble()),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.4,
                          color: const Color(0xFF00D9FF),
                          barWidth: 2.5,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00D9FF).withValues(alpha: 0.2),
                                const Color(0xFF00D9FF).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),

        // Mülk bazlı doluluk
        ...byProp.take(5).map((item) => _buildPropertyOccupancyRow(item)),

        // Boş daire yaşlandırma
        _buildVacantAgingCard(p['vacant_aging']),
      ],
    );
  }

  Widget _miniKpi(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color, fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyOccupancyRow(Map<String, dynamic> item) {
    final rate = (item['occupancy_rate'] ?? 0).toDouble();
    final color = rate >= 80 ? AppColors.success : (rate >= 50 ? AppColors.warning : AppColors.error);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['property_name'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['occupied_units']}/${item['total_units']} daire dolu',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${rate.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color, fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacantAgingCard(List<dynamic>? vacantList) {
    if (vacantList == null || vacantList.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_rounded, color: AppColors.error, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Boş Daire Yaşlandırma',
                style: TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...vacantList.take(5).map((v) {
            final days = v['vacant_since_days'] ?? 0;
            final urgency = days > 60 ? AppColors.error : (days > 30 ? AppColors.warning : AppColors.success);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${v['property_name']} — ${v['door_number']}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (v['last_rent_price'] != null)
                    Text(
                      '₺${_fmt((v['last_rent_price'] as int))}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10),
                    ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgency.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$days gün',
                      style: TextStyle(
                        color: urgency, fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // B. KİRACI SİRKÜLASYONU
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTenantChurnSection(Map<String, dynamic>? t) {
    if (t == null) return _emptyStateCard('Kiracı verisi yok');

    final monthlyFlow = (t['monthly_flow'] as List<dynamic>? ?? []);
    if (monthlyFlow.isEmpty) return _emptyStateCard('Kiracı akış verisi yok');

    final maxVal = monthlyFlow.fold<double>(1, (max, m) {
      final v = ((m['new_tenants'] ?? 0) + (m['departed_tenants'] ?? 0)).toDouble();
      return v > max ? v : max;
    });

    return Column(
      children: [
        // KPI chips
        _glassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _kpiChip('Aktif Kiracı', '${t['total_active_tenants'] ?? 0}', Icons.person_rounded, const Color(0xFFA78BFA)),
              const SizedBox(width: 10),
              _kpiChip('Ort. Kalış', '${t['avg_tenancy_months'] ?? 0} ay', Icons.schedule_rounded, const Color(0xFFFFB800)),
              const SizedBox(width: 10),
              _kpiChip('Churn Rate', '${t['churn_rate_percent'] ?? 0}%', Icons.trending_down_rounded, AppColors.error),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bar chart
        _glassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aylık Giriş / Çıkış',
                style: TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal * 1.3,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1A1A2E),
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, _, rod, __) {
                          final label = rod.color == AppColors.success ? 'Giriş' : 'Çıkış';
                          return BarTooltipItem(
                            '$label: ${rod.toY.toInt()}',
                            const TextStyle(color: Colors.white, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (val, _) {
                            if (val.toInt() >= monthlyFlow.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                monthlyFlow[val.toInt()]['month'].toString().substring(5),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: false),
                    barGroups: List.generate(monthlyFlow.length, (i) {
                      final m = monthlyFlow[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (m['new_tenants'] ?? 0).toDouble(),
                            color: AppColors.success,
                            width: 7,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                          ),
                          BarChartRodData(
                            toY: (m['departed_tenants'] ?? 0).toDouble(),
                            color: AppColors.error,
                            width: 7,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot('Yeni Kiracı', AppColors.success),
                  const SizedBox(width: 24),
                  _legendDot('Ayrılan', AppColors.error),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color, fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // C. FİNANSAL YILLIK
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFinancialSection(Map<String, dynamic>? f) {
    if (f == null) return _emptyStateCard('Finansal veri yok');

    final monthly = (f['monthly_breakdown'] as List<dynamic>? ?? []);
    final categories = (f['category_trends'] as List<dynamic>? ?? []);
    final last12 = monthly.length > 12 ? monthly.sublist(monthly.length - 12) : monthly;

    // Max for charts
    final maxVal = last12.fold<double>(1, (max, m) {
      final v = ((m['total_income'] ?? 0) + (m['total_expense'] ?? 0)).toDouble();
      return v > max ? v : max;
    });

    // Previous year comparison data
    final prevYearIncome = f['previous_year_income'] ?? 0;
    final prevYearExpense = f['previous_year_expense'] ?? 0;
    final curYearIncome = f['current_year_income'] ?? 0;
    final curYearExpense = f['current_year_expense'] ?? 0;

    return Column(
      children: [
        // Yıl özeti kartları
        Row(
          children: [
            Expanded(
              child: _glassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.trending_up_rounded, color: AppColors.success, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Cari Yıl', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _yearBar('Gelir', curYearIncome, prevYearIncome, AppColors.success),
                    const SizedBox(height: 8),
                    _yearBar('Gider', curYearExpense, prevYearExpense, AppColors.error),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _glassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Kar / Zarar', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          '₺${_fmt(f['current_year_net'] ?? 0)}',
                          style: TextStyle(
                            color: (f['current_year_net'] ?? 0) >= 0 ? AppColors.success : AppColors.error,
                            fontSize: 18, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _glassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gelir Büyüme', style: TextStyle(color: Colors.white, fontSize: 10)),
                            Text(
                              '${f['income_growth_percent'] ?? 0}%',
                              style: TextStyle(
                                color: (f['income_growth_percent'] ?? 0) >= 0 ? AppColors.success : AppColors.error,
                                fontSize: 12, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gider Büyüme', style: TextStyle(color: Colors.white, fontSize: 10)),
                            Text(
                              '${f['expense_growth_percent'] ?? 0}%',
                              style: TextStyle(
                                color: (f['expense_growth_percent'] ?? 0) <= 0 ? AppColors.success : AppColors.error,
                                fontSize: 12, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Gelir/Gider Bar Chart — 12 ay
        _glassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aylık Gelir / Gider Karşılaştırması',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1A1A2E),
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, _, rod, __) {
                          final label = rod.color == AppColors.success ? 'Gelir' : 'Gider';
                          return BarTooltipItem(
                            '$label: ₺${_fmt(rod.toY.toInt())}',
                            const TextStyle(color: Colors.white, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (val, _) {
                            if (val.toInt() >= last12.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                last12[val.toInt()]['month'].toString().substring(5),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: false),
                    barGroups: List.generate(last12.length, (i) {
                      final m = last12[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (m['total_income'] ?? 0).toDouble(),
                            color: AppColors.success,
                            width: 8,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                          ),
                          BarChartRodData(
                            toY: (m['total_expense'] ?? 0).toDouble(),
                            color: AppColors.error,
                            width: 8,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot('Gelir', AppColors.success),
                  const SizedBox(width: 24),
                  _legendDot('Gider', AppColors.error),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Kategori Bazlı Gider Dağılımı — Stacked Area (simulated with multiple fills)
        if (categories.isNotEmpty)
          _buildCategoryExpenseChart(categories),
        const SizedBox(height: 14),

        // Net Kar Marjı Trendi — Çizgi Grafik
        if (last12.isNotEmpty)
          _glassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded, size: 16, color: const Color(0xFFFFB800).withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    const Text(
                      'Net Kar Marjı Trendi',
                      style: TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: 50000,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: Colors.white.withValues(alpha: 0.04),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            interval: 2,
                            getTitlesWidget: (val, _) {
                              if (val.toInt() >= last12.length) return const SizedBox();
                              return Text(
                                last12[val.toInt()]['month'].toString().substring(5),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 9,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 50000,
                            getTitlesWidget: (val, _) => Text(
                              '₺${_fmt(val.toInt())}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            last12.length,
                            (i) => FlSpot(i.toDouble(), (last12[i]['net_balance'] ?? 0).toDouble()),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.4,
                          color: const Color(0xFFFFB800),
                          barWidth: 2.5,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFB800).withValues(alpha: 0.18),
                                const Color(0xFFFFB800).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _yearBar(String label, int current, int previous, Color color) {
    final maxVal = current > previous ? current.toDouble() : previous.toDouble();
    final pct = maxVal > 0 ? (current / maxVal * 100) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
            Text(
              '₺${_fmt(current)}',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct / 100,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Geçen yıl: ₺${_fmt(previous)}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildCategoryExpenseChart(List<dynamic> categories) {
    // Simulate stacked area with layered filled line charts
    // Colors for expense categories
    final colors = [
      const Color(0xFFFF6B6B), // maintenance
      const Color(0xFFFFD93D), // utility
      const Color(0xFF4ECDC4), // other
    ];

    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stacked_bar_chart_rounded, size: 16, color: const Color(0xFFFF6B6B).withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              const Text(
                'Kategori Bazlı Gider Dağılımı',
                style: TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: Colors.white.withValues(alpha: 0.04),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (val, _) {
                        if (val.toInt() >= categories.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            categories[val.toInt()]['month'].toString().substring(5),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Maintenance
                  LineChartBarData(
                    spots: List.generate(
                      categories.length,
                      (i) => FlSpot(i.toDouble(), (categories[i]['maintenance_expense'] ?? 0).toDouble()),
                    ),
                    isCurved: true,
                    color: colors[0],
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors[0].withValues(alpha: 0.12),
                    ),
                  ),
                  // Utility
                  LineChartBarData(
                    spots: List.generate(
                      categories.length,
                      (i) => FlSpot(i.toDouble(), (categories[i]['utility_expense'] ?? 0).toDouble()),
                    ),
                    isCurved: true,
                    color: colors[1],
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors[1].withValues(alpha: 0.12),
                    ),
                  ),
                  // Other
                  LineChartBarData(
                    spots: List.generate(
                      categories.length,
                      (i) => FlSpot(i.toDouble(), (categories[i]['other_expense'] ?? 0).toDouble()),
                    ),
                    isCurved: true,
                    color: colors[2],
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors[2].withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot('Tamirat', colors[0]),
              const SizedBox(width: 20),
              _legendDot('Fatura', colors[1]),
              const SizedBox(width: 20),
              _legendDot('Diğer', colors[2]),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // D. TAHSİLAT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCollectionSection(Map<String, dynamic>? c) {
    if (c == null) return _emptyStateCard('Tahsilat verisi yok');

    final monthly = (c['monthly_rates'] as List<dynamic>? ?? []);
    final last6 = monthly.length > 6 ? monthly.sublist(monthly.length - 6) : monthly;

    return Column(
      children: [
        // KPI'lar
        Row(
          children: [
            Expanded(child: _glassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart_rounded, size: 15, color: AppColors.success,),
                      const SizedBox(width: 6),
                      const Text('Tahsilat', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${c['overall_collection_rate'] ?? 0}%',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                ],
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: _glassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: AppColors.warning),
                      const SizedBox(width: 6),
                      const Text('Ort. Gecikme', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${c['avg_delay_days'] ?? 0} gün',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                ],
              ),
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _glassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.success),
                      const SizedBox(width: 6),
                      const Text('Zamanında Ödeme', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${c['on_time_payment_rate'] ?? 0}%',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                ],
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: _glassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pending_actions_rounded, size: 15, color: AppColors.error),
                      const SizedBox(width: 6),
                      const Text('Bekleyen', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₺${_fmt(c['total_outstanding'] ?? 0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                ],
              ),
            )),
          ],
        ),
        const SizedBox(height: 14),

        // Tahsilat trend çizgi grafik
        if (last6.isNotEmpty)
          _glassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded, size: 16, color: AppColors.success.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    const Text(
                      'Tahsilat Oranı Trendi',
                      style: TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 130,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: Colors.white.withValues(alpha: 0.04),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            getTitlesWidget: (val, _) {
                              if (val.toInt() >= last6.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  last6[val.toInt()]['month'].toString().substring(5),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 25,
                            getTitlesWidget: (val, _) => Text(
                              '${val.toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            last6.length,
                            (i) => FlSpot(i.toDouble(), (last6[i]['collection_rate_percent'] ?? 0).toDouble()),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: AppColors.success,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 3.5,
                              color: AppColors.success,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.success.withValues(alpha: 0.18),
                                AppColors.success.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Bu Ay: ₺${_fmt(last6.last['collected_amount'] ?? 0)} / ₺${_fmt(last6.last['expected_amount'] ?? 0)}',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _glassCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _emptyStateCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
