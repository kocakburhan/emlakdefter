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
  final _floorsController = TextEditingController(text: "1");
  final _unitsController = TextEditingController(text: "2");
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

  // Otonom Üretim sonucu
  bool _isCreated = false;
  int _createdUnitsCount = 0;

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
    _floorsController.dispose();
    _unitsController.dispose();
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
      final response = await ref.read(propertiesProvider.notifier).createProperty(
        name: name,
        type: _typeString,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        centralDues: int.tryParse(_duesController.text) ?? 0,
        startFloor: isApartment || isVilla ? 1 : null,
        endFloor: isApartment || isVilla ? (int.tryParse(_floorsController.text) ?? 1) : null,
        unitsPerFloor: isApartment
            ? (int.tryParse(_unitsController.text) ?? 1)
            : (isVilla ? 1 : (int.tryParse(_shopCountController.text) ?? 1)),
      );

      if (mounted) {
        if (response != null) {
          // Sunucu tarafından döndürülen birim sayısını kullan (§4.1.2-B doğrulaması)
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
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.add_location_alt, color: AppColors.accent, size: 24),
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
                                  style: TextStyle(fontSize: 12, color: AppColors.textBody),
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
                          color: AppColors.textBody,
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
                            backgroundColor: AppColors.accent,
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
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.rocket_launch, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          "OTONOM İNŞAATA BAŞLA",
                                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
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
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textBody,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textBody,
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

  Widget _buildApartmentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "OTONOM ÜRETİM PARAMETRELERİ",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textBody,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildNumberField(_floorsController, "Kat Sayısı")),
            const SizedBox(width: 12),
            Expanded(child: _buildNumberField(_unitsController, "Daire/Kat")),
          ],
        ),
        const SizedBox(height: 12),
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

  Widget _buildVillaFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "VİLLA BİLGİLERİ",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textBody,
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
            color: AppColors.textBody,
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
            color: AppColors.textBody,
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
              color: AppColors.textBody,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textBody),
          ),
        ],
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textBody),
        hintStyle: TextStyle(color: AppColors.textBody.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTextField2(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textBody),
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textBody),
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