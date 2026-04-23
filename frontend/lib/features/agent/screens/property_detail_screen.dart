import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import 'unit_detail_screen.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;

  const PropertyDetailScreen({
    Key? key,
    required this.propertyId,
    required this.propertyName,
  }) : super(key: key);

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen>
    with TickerProviderStateMixin {
  List<dynamic> _units = [];
  bool _isLoading = true;
  String? _error;
  bool _showAddUnit = false;
  final _doorController = TextEditingController();
  final _floorController = TextEditingController(text: "0");
  final _duesController = TextEditingController(text: "0");

  late AnimationController _animController;
  late Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeSlide = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _fetchProperty();
  }

  @override
  void dispose() {
    _animController.dispose();
    _doorController.dispose();
    _floorController.dispose();
    _duesController.dispose();
    super.dispose();
  }

  Future<void> _fetchProperty() async {
    setState(() => _isLoading = true);
    _animController.forward(from: 0);
    try {
      final response = await ApiClient.dio.get('/properties/${widget.propertyId}');
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _units = response.data['units'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _addUnit() async {
    if (_doorController.text.trim().isEmpty) return;
    try {
      final resp = await ApiClient.dio.post(
        '/properties/${widget.propertyId}/units',
        data: {
          'door_number': _doorController.text.trim(),
          'floor': _floorController.text.trim(),
          'dues_amount': int.tryParse(_duesController.text) ?? 0,
        },
      );
      if (resp.statusCode == 201) {
        _doorController.clear();
        setState(() => _showAddUnit = false);
        await _fetchProperty();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Birim ekleme hatası: $e")),
      );
    }
  }

  Future<void> _showBroadcastDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.campaign, color: AppColors.charcoal, size: 22),
            SizedBox(width: 10),
            Text("Toplu Bildirim", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Başlık",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Mesaj",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Gönder"),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty && bodyController.text.isNotEmpty) {
      try {
        final resp = await ApiClient.dio.post(
          '/properties/${widget.propertyId}/broadcast-notification',
          data: {
            'title': titleController.text.trim(),
            'body': bodyController.text.trim(),
          },
        );
        if (resp.statusCode == 200) {
          final data = resp.data;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text("✅ ${data['message']}"),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bildirim hatası: $e")),
        );
      }
    }
  }

  int get _occupiedCount => _units.where((u) => u['status'] == 'occupied').length;
  int get _vacantCount => _units.where((u) => u['status'] == 'vacant').length;
  double get _occupancyRate => _units.isEmpty ? 0.0 : (_occupiedCount / _units.length) * 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _fadeSlide,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeSlide.value,
            child: child,
          );
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── SLIVER APP BAR ──────────────────────────────────────────
            SliverAppBar(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.charcoal,
              pinned: true,
              expandedHeight: 120,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.propertyName,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_units.isNotEmpty)
                      Text(
                        "$_occupiedCount Dolu · $_vacantCount Müsait · %${_occupancyRate.toStringAsFixed(0)} Doluluk",
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.refresh, size: 20),
                  ),
                  onPressed: _fetchProperty,
                ),
                const SizedBox(width: 4),
              ],
            ),

            // ── ACTION BAR (§4.1.2-C) ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        Icons.campaign,
                        "Toplu Bildirim",
                        AppColors.charcoal,
                        _showBroadcastDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionBtn(
                        Icons.add_circle_outline,
                        "Birim Ekle",
                        AppColors.success,
                        () => setState(() => _showAddUnit = !_showAddUnit),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── ADD UNIT FORM ───────────────────────────────────────────
            if (_showAddUnit)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "YENİ BİRİM EKLE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _doorController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Kapı No",
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: _floorController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Kat",
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: _duesController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Aidat",
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: _addUnit,
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.check, color: AppColors.success, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── OCCUPANCY PROGRESS ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_units.length} Toplam Birim",
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          Text(
                            "%${_occupancyRate.toStringAsFixed(0)} Doluluk",
                            style: TextStyle(
                              color: _occupancyRate >= 80
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _occupancyRate / 100,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          color: _occupancyRate >= 80
                              ? AppColors.success
                              : AppColors.warning,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── UNITS GRID ───────────────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.charcoal),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        "Mülk yüklenemedi",
                        style: const TextStyle(color: AppColors.charcoal, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _fetchProperty,
                        child: const Text("Tekrar dene"),
                      ),
                    ],
                  ),
                ),
              )
            else if (_units.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home_outlined, size: 48, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Bu mülkte henüz birim yok",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _showAddUnit = true),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Birim ekle"),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final unit = _units[index];
                      return _buildUnitCard(unit, index);
                    },
                    childCount: _units.length,
                  ),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> unit, int index) {
    final status = unit['status'] ?? 'vacant';
    final isOccupied = status == 'occupied';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 40).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.85 + (0.15 * value),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => UnitDetailScreen(
                propertyId: widget.propertyId,
                unitId: unit['id'],
                propertyName: widget.propertyName,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOccupied
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.warning.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isOccupied ? AppColors.success : AppColors.warning)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOccupied ? Icons.home : Icons.home_outlined,
                      color: isOccupied ? AppColors.success : AppColors.warning,
                      size: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isOccupied ? AppColors.success : AppColors.warning)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOccupied ? "Dolu" : "Boş",
                      style: TextStyle(
                        color: isOccupied ? AppColors.success : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                "Kapı ${unit['door_number'] ?? '-'}",
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Kat ${unit['floor'] ?? '-'}${isOccupied ? " · ${unit['rent_price'] ?? '?'} ₺" : ""}",
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}