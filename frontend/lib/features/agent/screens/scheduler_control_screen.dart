import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';

/// §3.3 APScheduler Yönetim Paneli — Komut Merkezi Tasarımı
/// Endüstriyel/utilitarian : Hardedges, monospace accents, terminal vibes
class SchedulerControlScreen extends StatefulWidget {
  const SchedulerControlScreen({Key? key}) : super(key: key);

  @override
  State<SchedulerControlScreen> createState() => _SchedulerControlScreenState();
}

class _SchedulerControlScreenState extends State<SchedulerControlScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _statusMessage;

  // Scheduler state
  bool _schedulerRunning = false;
  List<SchedulerJob> _jobs = [];
  SchedulerStats? _stats;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadSchedulerData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedulerData() async {
    setState(() => _isLoading = true);
    try {
      final dio = ApiClient.dio;

      // Fetch status and stats in parallel
      final responses = await Future.wait([
        dio.get('/scheduler/status'),
        dio.get('/scheduler/stats'),
      ]);

      final statusData = responses[0].data;
      final statsData = responses[1].data;

      setState(() {
        _schedulerRunning = statusData['running'] ?? false;
        _jobs = (statusData['jobs'] as List).map((j) => SchedulerJob.fromJson(j)).toList();
        _stats = SchedulerStats.fromJson(statsData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Bağlantı hatası: $e';
      });
    }
  }

  Future<void> _triggerJob(String jobType) async {
    setState(() => _isLoading = true);
    try {
      final dio = ApiClient.dio;
      final endpoint = jobType == 'monthly_dues'
          ? '/scheduler/trigger/monthly-dues'
          : '/scheduler/trigger/payment-reminders';

      final response = await dio.post(endpoint);

      setState(() {
        _isLoading = false;
        _statusMessage = response.data['message'] ?? 'İşlem tamamlandı';
      });

      // Reload data after trigger
      await Future.delayed(const Duration(seconds: 1));
      _loadSchedulerData();

      // Clear message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _statusMessage = null);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Hata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'OTOMASYON KOMUT MERKEZİ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.charcoal),
            onPressed: _isLoading ? null : _loadSchedulerData,
          ),
        ],
      ),
      body: _isLoading && _stats == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.charcoal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STATUS INDICATOR
                  _buildStatusPanel(),
                  const SizedBox(height: 24),

                  // STATS GRID
                  if (_stats != null) ...[
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                  ],

                  // SCHEDULED JOBS
                  _buildJobsSection(),
                  const SizedBox(height: 24),

                  // MANUAL TRIGGERS
                  _buildManualTriggers(),
                  const SizedBox(height: 24),

                  // STATUS MESSAGE
                  if (_statusMessage != null) _buildStatusMessage(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: _schedulerRunning ? AppColors.charcoal.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Pulsing indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _schedulerRunning
                      ? AppColors.charcoal.withValues(alpha: _pulseAnimation.value)
                      : Colors.red.withValues(alpha: _pulseAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color: (_schedulerRunning ? AppColors.charcoal : Colors.red)
                          .withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _schedulerRunning ? 'SCHEDULER AKTİF' : 'SCHEDULER DURDURULMUŞ',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _schedulerRunning
                      ? 'Otomatik işler çalışıyor • Sonraki: ${_jobs.isNotEmpty ? _formatNextRun(_jobs.first.nextRun) : "—"}'
                      : 'Arka plan işleri pasif • Manuel tetikleme gerekli',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '// TAKVİM İSTATİSTİKLERİ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.charcoal,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('AKTİF KİRACILAR', '${_stats!.totalActiveTenants}', AppColors.charcoal)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('BU AY BEKLEYEN', '${_stats!.pendingSchedulesThisMonth}', Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('GEÇİKMİŞ', '${_stats!.overdueCount}', Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('3 GÜN İÇİNDE', '${_stats!.upcoming3Days}', Colors.amber)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '// PLANLI İŞLER',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.charcoal,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...(_jobs.isEmpty
            ? [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Sistemde planlı iş yok',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                )
              ]
            : _jobs.map((job) => _buildJobCard(job))),
      ],
    );
  }

  Widget _buildJobCard(SchedulerJob job) {
    final isMonthlyDues = job.id.contains('monthly') || job.name.toLowerCase().contains('dues');
    final icon = isMonthlyDues ? Icons.calendar_month : Icons.notifications_active;
    final scheduleText = isMonthlyDues ? 'Her ayın 1. günü 01:00' : 'Her gün 09:00';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.charcoal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: AppColors.charcoal, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduleText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: job.active
                  ? AppColors.charcoal.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              job.active ? 'AKTİF' : 'PASİF',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: job.active ? AppColors.charcoal : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTriggers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '// MANUEL TETİKLEME',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.charcoal,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTriggerButton(
                'KİRA TAHACCUKU',
                Icons.calendar_month,
                Colors.orange,
                () => _triggerJob('monthly_dues'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTriggerButton(
                'HATIRLATMA GÖNDER',
                Icons.send,
                Colors.cyan,
                () => _triggerJob('payment_reminders'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '⚠️ Bu işlemler normalde otomatik olarak çalışır. Test ve debug için kullanın.',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.charcoal.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.charcoal.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.charcoal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNextRun(String? isoString) {
    if (isoString == null) return '—';
    try {
      final dt = DateTime.parse(isoString);
      final local = dt.toLocal();
      return '${local.day}.${local.month}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────────────────

class SchedulerJob {
  final String id;
  final String name;
  final String? nextRun;
  final int pendingRuns;
  final bool active;

  SchedulerJob({
    required this.id,
    required this.name,
    this.nextRun,
    this.pendingRuns = 0,
    this.active = false,
  });

  factory SchedulerJob.fromJson(Map<String, dynamic> json) {
    return SchedulerJob(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nextRun: json['next_run'],
      pendingRuns: json['pending_runs'] ?? 0,
      active: json['active'] ?? false,
    );
  }
}

class SchedulerStats {
  final int totalActiveTenants;
  final int pendingSchedulesThisMonth;
  final int overdueCount;
  final int upcoming3Days;
  final String? nextScheduledRun;

  SchedulerStats({
    required this.totalActiveTenants,
    required this.pendingSchedulesThisMonth,
    required this.overdueCount,
    required this.upcoming3Days,
    this.nextScheduledRun,
  });

  factory SchedulerStats.fromJson(Map<String, dynamic> json) {
    return SchedulerStats(
      totalActiveTenants: json['total_active_tenants'] ?? 0,
      pendingSchedulesThisMonth: json['pending_schedules_this_month'] ?? 0,
      overdueCount: json['overdue_count'] ?? 0,
      upcoming3Days: json['upcoming_3_days'] ?? 0,
      nextScheduledRun: json['next_scheduled_run'],
    );
  }
}