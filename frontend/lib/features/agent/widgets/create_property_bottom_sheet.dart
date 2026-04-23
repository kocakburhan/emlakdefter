import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';
import '../providers/properties_provider.dart';

enum PropertyFormType {
  apartment,
  villa,
  land,
  commercial,
}

class FloorConfigEntry {
  final int floor;
  int units;
  bool excluded;

  FloorConfigEntry({required this.floor, this.units = 2, this.excluded = false});

  FloorConfigEntry copyWith({int? units, bool? excluded}) {
    return FloorConfigEntry(
      floor: floor,
      units: units ?? this.units,
      excluded: excluded ?? this.excluded,
    );
  }
}

class CreatePropertyBottomSheet extends ConsumerStatefulWidget {
  const CreatePropertyBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<CreatePropertyBottomSheet> createState() => _CreatePropertyBottomSheetState();
}

class _CreatePropertyBottomSheetState extends ConsumerState<CreatePropertyBottomSheet>
    with TickerProviderStateMixin {
  PropertyFormType _selectedType = PropertyFormType.apartment;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _blocksController = TextEditingController(text: "1");
  final _endFloorController = TextEditingController(text: "8");
  final _duesController = TextEditingController(text: "0");
  final _rentController = TextEditingController(text: "0");

  // Land-specific
  final _parcelController = TextEditingController();
  final _areaController = TextEditingController();
  final _cadastreController = TextEditingController();

  // Commercial-specific
  final _shopCountController = TextEditingController(text: "1");

  late AnimationController _animController;
  late Animation<double> _fadeSlide;

  // Bina Özellikleri Seçimi
  final Set<String> _selectedFeatures = {};

  // Otonom Üretim sonucu
  bool _isCreated = false;
  int _createdUnitsCount = 0;

  // ═══════════════════════════════════════════════════════════════
  // TEST 4 — OTONOM DAİRE ÜRETİM MOTORU: YENİ ÇOK ADIMLI UI
  // ═══════════════════════════════════════════════════════════════

  // Kat yapılandırma adımları
  int _currentStep = 0; // 0=Parametreler, 1=Kat Düzenleme, 2=Ön İzleme

  // Başlangıç katı (seçim dropdown ile)
  int _startFloor = 1;

  // Esnek kat yapılandırması (her kat için birim sayısı)
  List<FloorConfigEntry> _floorConfig = [];

  // Yaygın birim sayısı (tüm katlara uygulanır)
  int _defaultUnitsPerFloor = 2;

  // Kat listesi (-3'ten max kata)
  List<int> get _floorRange {
    final endFloor = int.tryParse(_endFloorController.text) ?? 8;
    return List.generate(endFloor - _startFloor + 1, (i) => _startFloor + i);
  }

  // Tüm hariç olmayan katlardaki toplam birim sayısı
  int get _totalUnits {
    return _floorConfig.where((f) => !f.excluded).fold(0, (sum, f) => sum + f.units);
  }

  // Toplam kat sayısı (hariç olanlar dahil değil)
  int get _totalFloors {
    return _floorConfig.where((f) => !f.excluded).length;
  }

  // Kat listesini oluştur / güncelle
  void _initFloorConfig() {
    _floorConfig = _floorRange.map((f) => FloorConfigEntry(
      floor: f,
      units: _defaultUnitsPerFloor,
      excluded: false,
    )).toList();
  }

  // Tüm katlara varsayılan birim sayısını uygula
  void _applyDefaultToAllFloors() {
    setState(() {
      for (var entry in _floorConfig) {
        entry.units = _defaultUnitsPerFloor;
        entry.excluded = false;
      }
    });
  }

  // Kapı numarası tahmini (ön izleme için)
  List<String> _previewDoorNumbers() {
    final List<String> doors = [];
    int doorCounter = 1;
    for (var entry in _floorConfig) {
      if (!entry.excluded) {
        for (int i = 0; i < entry.units; i++) {
          doors.add(doorCounter.toString());
          doorCounter++;
        }
      }
    }
    return doors;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeSlide = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _blocksController.dispose();
    _endFloorController.dispose();
    _duesController.dispose();
    _rentController.dispose();
    _parcelController.dispose();
    _areaController.dispose();
    _cadastreController.dispose();
    _shopCountController.dispose();
    super.dispose();
  }

  String get _typeString {
    switch (_selectedType) {
      case PropertyFormType.apartment:
        return 'apartment';
      case PropertyFormType.villa:
        return 'villa';
      case PropertyFormType.land:
        return 'land';
      case PropertyFormType.commercial:
        return 'commercial';
    }
  }

  void _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen mülk adını girin!")),
      );
      return;
    }

    final isApartment = _selectedType == PropertyFormType.apartment;
    final isVilla = _selectedType == PropertyFormType.villa;

    setState(() => _isLoading = true);

    try {
      // Seçili bina özelliklerini Map'e dönüştür
      final featuresMap = <String, dynamic>{};
      for (final f in _selectedFeatures) {
        featuresMap[f] = true;
      }

      // floor_config hazırla
      List<Map<String, dynamic>>? floorConfigPayload;
      if (isApartment && _floorConfig.isNotEmpty) {
        floorConfigPayload = _floorConfig.map((f) => {
          'floor': f.floor,
          'units': f.units,
          'exclude': f.excluded,
        }).toList();
      }

      final response = await ref.read(propertiesProvider.notifier).createProperty(
        name: name,
        type: _typeString,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        centralDues: int.tryParse(_duesController.text) ?? 0,
        features: featuresMap.isNotEmpty ? featuresMap : null,
        floorConfig: floorConfigPayload,
      );

      if (mounted) {
        if (response != null) {
          _createdUnitsCount = response;
          setState(() {
            _isCreated = true;
            _isLoading = false;
          });
          await Future.delayed(const Duration(milliseconds: 1800));
          if (mounted) Navigator.of(context).pop();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text("❌ $name oluşturulamadı!"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Hata: $e")),
        );
      }
    }
  }

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
        padding: EdgeInsets.fromLTRB(0, 24, 0, 24 + bottomInset),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: AnimatedBuilder(
                animation: _fadeSlide,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeSlide.value,
                    child: child,
                  );
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.charcoal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.add_location_alt, color: AppColors.charcoal, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Yeni Mülk Ekle",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "Portföyünüze yeni bir gayrimenkul ekleyin",
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── MÜLK TİPİ SEÇİMİ (Zorunlu Adım 1) ────────────────
                      const Text(
                        "MÜLK TİPİ",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTypeChip("APARTMAN / SİTE", Icons.apartment, PropertyFormType.apartment),
                            const SizedBox(width: 8),
                            _buildTypeChip("MÜSTAKİL EV", Icons.villa, PropertyFormType.villa),
                            const SizedBox(width: 8),
                            _buildTypeChip("ARSA / TARLA", Icons.landscape, PropertyFormType.land),
                            const SizedBox(width: 8),
                            _buildTypeChip("DÜKKAN", Icons.storefront, PropertyFormType.commercial),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── ORTAK ALANLAR ────────────────────────────────────
                      _buildTextField(
                        controller: _nameController,
                        label: "Mülk Adı",
                        hint: "Örn: Boğaz Evleri Sitesi",
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: "Adres (Opsiyonel)",
                        hint: "Örn: Atatürk Cad. No:42, Beşiktaş",
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 16),

                      // ── TİPE GÖRE DİNAMİK ALANLAR ──────────────────────
                      _buildDynamicFields(),

                      const SizedBox(height: 28),

                      // ── ONAY BUTONU ────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.charcoal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      "OTONOM ÜRETİM ÇALIŞTIRILIYOR...",
                                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
                                    ),
                                  ],
                                )
                              : _isCreated
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "✅ $_createdUnitsCount DAIRE OLUŞTURULDU!",
                                          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.rocket_launch, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedType == PropertyFormType.apartment
                                              ? "OTONOM İNŞAATA BAŞLA"
                                              : "MÜLK EKLE",
                                          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon, PropertyFormType type) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.charcoal : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.charcoal : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicFields() {
    switch (_selectedType) {
      case PropertyFormType.apartment:
        return _buildApartmentFields();
      case PropertyFormType.villa:
        return _buildVillaFields();
      case PropertyFormType.land:
        return _buildLandFields();
      case PropertyFormType.commercial:
        return _buildCommercialFields();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TEST 4 — APARTMAN ALANI: ÇOK ADIMLI KAT YAPILANDIRMA UI
  // ═══════════════════════════════════════════════════════════════

  Widget _buildApartmentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        const Text(
          "OTONOM ÜRETİM PARAMETRELERİ",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // ── ADIM GÖSTERGESİ ─────────────────────────────────────
        _buildStepIndicator(),
        const SizedBox(height: 16),

        // ── ADIM 0: TEMEL PARAMETRELER ──────────────────────────
        if (_currentStep == 0) _buildStep0_Params(),
        if (_currentStep == 1) _buildStep1_FloorEdit(),
        if (_currentStep == 2) _buildStep2_Preview(),

        const SizedBox(height: 20),

        // ── AIDAT VE ÖZELLİKLER ──────────────────────────────────
        Row(
          children: [
            Expanded(child: _buildNumberField(_blocksController, "Blok Sayısı")),
            const SizedBox(width: 12),
            Expanded(child: _buildNumberField(_duesController, "Aidat (₺)")),
          ],
        ),
        const SizedBox(height: 12),
        _buildFeaturesChecklist(),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Kat Seçimi', 'Kat Düzenle', 'Ön İzleme'];
    return Row(
      children: List.generate(steps.length, (idx) {
        final isActive = idx == _currentStep;
        final isCompleted = idx < _currentStep;
        return Expanded(
          child: GestureDetector(
            onTap: idx < _currentStep ? () => setState(() => _currentStep = idx) : null,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.charcoal : (isCompleted ? Colors.green : AppColors.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? AppColors.charcoal : Colors.white12,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isActive ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    steps[idx],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (idx < steps.length - 1)
                  Container(
                    width: 20,
                    height: 1,
                    color: isCompleted ? Colors.green : Colors.white12,
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ADIM 0: Başlangıç/Bitiş katı ve varsayılan birim sayısı
  Widget _buildStep0_Params() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlangıç katı dropdown
        Row(
          children: [
            const Expanded(
              flex: 1,
              child: Text(
                "Başlangıç Katı",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _startFloor,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    items: List.generate(25, (i) {
                      final floor = i - 4; // -4'ten 20'ye
                      return DropdownMenuItem(
                        value: floor,
                        child: Text(_floorLabel(floor)),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _startFloor = v;
                          _initFloorConfig();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bitiş katı
        Row(
          children: [
            const Expanded(
              flex: 1,
              child: Text(
                "En Üst Kat",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _endFloorController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Örn: 12",
                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  setState(() => _initFloorConfig());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Varsayılan birim/kat
        Row(
          children: [
            const Expanded(
              flex: 1,
              child: Text(
                "Her Katta Kaç Daire",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              flex: 1,
              child: TextField(
                controller: TextEditingController(text: _defaultUnitsPerFloor.toString()),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Örn: 4",
                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _defaultUnitsPerFloor = int.tryParse(v) ?? 2;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tüm katlara uygula butonu
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _initFloorConfig();
                _applyDefaultToAllFloors();
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              "Tüm katlara $_defaultUnitsPerFloor daire uygula",
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.charcoal,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Özet bilgi
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.charcoal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.charcoal.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.charcoal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Kat aralığı: ${_floorLabel(_startFloor)} → ${_floorLabel(int.tryParse(_endFloorController.text) ?? 8)}\n"
                  "Toplam kat: ${_floorRange.length} | Toplam daire: ~${_floorRange.length * _defaultUnitsPerFloor}",
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // İleri butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _initFloorConfig();
              setState(() => _currentStep = 1);
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text("Katları Düzenle →"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ADIM 1: Her kat için birim sayısını düzenleme
  Widget _buildStep1_FloorEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Geri + Başlık
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _currentStep = 0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back, size: 16, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Her Katı Düzenle",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$_totalFloors kat × $_totalUnits daire",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.charcoal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Kat listesi
        ...List.generate(_floorConfig.length, (idx) {
          final entry = _floorConfig[idx];
          return _buildFloorRow(entry, idx);
        }),

        const SizedBox(height: 16),

        // Hızlı aksiyonlar
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    for (var e in _floorConfig) {
                      if (e.units > 1) e.units--;
                    }
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("-1 Tüm Katlardan", style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    for (var e in _floorConfig) {
                      e.units++;
                    }
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("+1 Tüm Katlara", style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Ön izleme butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _currentStep = 2),
            icon: const Icon(Icons.preview, size: 18),
            label: Text("Ön İzleme ($_totalUnits Daire) →"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ADIM 2: Ön izleme — tüm kapı numaralarını göster, çıkarılabilir
  Widget _buildStep2_Preview() {
    final doors = _previewDoorNumbers();
    final grouped = <int, List<String>>{};
    for (var entry in _floorConfig) {
      if (!entry.excluded) {
        final startDoor = grouped.isEmpty ? 1 : grouped.values.fold(0, (sum, list) => sum + list.length) + 1;
        final List<String> floorDoors = [];
        for (int i = 0; i < entry.units; i++) {
          floorDoors.add((startDoor + i).toString());
        }
        grouped[entry.floor] = floorDoors;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Geri + Başlık
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _currentStep = 1),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back, size: 16, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Ön İzleme",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Özet kartı
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.charcoal, AppColors.charcoal.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildSummaryBox("Toplam Kat", "$_totalFloors"),
              const SizedBox(width: 12),
              _buildSummaryBox("Toplam Daire", "$_totalUnits"),
              const SizedBox(width: 12),
              _buildSummaryBox("Kapı Aralığı", doors.isNotEmpty ? "1 - ${doors.last}" : "—"),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kat bazlı kapı listesi
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              children: _floorConfig.where((f) => !f.excluded).map((entry) {
                final floorDoors = grouped[entry.floor] ?? [];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.charcoal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _floorLabel(entry.floor),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.charcoal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: floorDoors.map((door) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.charcoal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Kapi $door",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            final idx = _floorConfig.indexOf(entry);
                            if (idx >= 0) {
                              _floorConfig[idx] = entry.copyWith(excluded: true);
                            }
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Geri + Oluştur
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("← Geri Düzenle"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _totalUnits > 0 ? _submit : null,
                icon: const Icon(Icons.check, size: 18),
                label: Text("$_totalUnits Daire Oluştur"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _totalUnits > 0 ? Colors.green.shade700 : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorRow(FloorConfigEntry entry, int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.excluded ? AppColors.surface.withValues(alpha: 0.3) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: entry.excluded ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // Kat numarası
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.excluded ? Colors.red.withValues(alpha: 0.1) : AppColors.charcoal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _floorLabel(entry.floor),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: entry.excluded ? Colors.red : AppColors.charcoal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Birim sayısı spinner
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: entry.units > 0
                      ? () {
                          setState(() {
                            _floorConfig[idx] = entry.copyWith(units: entry.units - 1);
                          });
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  color: AppColors.charcoal,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    entry.excluded ? "—" : "${entry.units}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: entry.excluded ? AppColors.textSecondary : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _floorConfig[idx] = entry.copyWith(units: entry.units + 1);
                    });
                  },
                  icon: const Icon(Icons.add_circle, size: 22),
                  color: AppColors.charcoal,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Hariç / Dahil toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _floorConfig[idx] = entry.copyWith(excluded: !entry.excluded);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: entry.excluded ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.excluded ? "Hariç" : "Dahil",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: entry.excluded ? Colors.red : Colors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _floorLabel(int floor) {
    if (floor < 0) return "B${floor.abs()}";
    if (floor == 0) return "Z";
    return "+$floor";
  }

  Widget _buildVillaFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "VİLLA BİLGİLERİ",
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
            Expanded(child: _buildNumberField(_rentController, "Kira (₺)")),
            const SizedBox(width: 12),
            Expanded(child: _buildNumberField(_duesController, "Aidat (₺)")),
          ],
        ),
        const SizedBox(height: 12),
        _buildFeaturesChecklist(),
      ],
    );
  }

  Widget _buildLandFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ARSA / TARLA BİLGİLERİ",
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
            Expanded(child: _buildTextField2(_parcelController, "Ada", "Örn: 1234")),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField2(_parcelController, "Parsel", "Örn: 567")),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField2(_cadastreController, "İmar Durumu", "Örn: Konut")),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField2(_areaController, "Alan (m²)", "Örn: 1200")),
          ],
        ),
      ],
    );
  }

  Widget _buildCommercialFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TİCARİ İŞYERİ BİLGİLERİ",
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
            Expanded(child: _buildNumberField(_shopCountController, "İşyeri Sayısı")),
            const SizedBox(width: 12),
            Expanded(child: _buildNumberField(_rentController, "Kira (₺)")),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildNumberField(_duesController, "Aidat (₺)")),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesChecklist() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "BİNA ÖZELLİKLERİ",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureChip(Icons.elevator, "Asansör"),
              _buildFeatureChip(Icons.local_parking, "Otopark"),
              _buildFeatureChip(Icons.pool, "Havuz"),
              _buildFeatureChip(Icons.solar_power, "Güneş Enerjisi"),
              _buildFeatureChip(Icons.security, "Güvenlik"),
              _buildFeatureChip(Icons.park, "Bahçe"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    final isSelected = _selectedFeatures.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFeatures.remove(label);
          } else {
            _selectedFeatures.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.charcoal : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.charcoal : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.charcoal,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: AppColors.charcoal, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.charcoal, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTextField2(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}