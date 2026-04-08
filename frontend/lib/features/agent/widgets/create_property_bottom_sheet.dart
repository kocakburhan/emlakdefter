import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';
import '../providers/properties_provider.dart';

class CreatePropertyBottomSheet extends ConsumerStatefulWidget {
  const CreatePropertyBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<CreatePropertyBottomSheet> createState() => _CreatePropertyBottomSheetState();
}

class _CreatePropertyBottomSheetState extends ConsumerState<CreatePropertyBottomSheet> {
  final _nameController = TextEditingController();
  final _blocksController = TextEditingController(text: "1");
  final _floorsController = TextEditingController(text: "1");
  final _unitsController = TextEditingController(text: "1");

  void _submit() async {
    final name = _nameController.text.trim();
    final blocks = int.tryParse(_blocksController.text) ?? 1;
    final floors = int.tryParse(_floorsController.text) ?? 1;
    final units = int.tryParse(_unitsController.text) ?? 1;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen site veya bina adını girin!")));
      return;
    }
    
    // Uygulamanın en heyecan verici tarafı: "Otonom Blok Yaratım Zekasına Bağlan!"
    await ref.read(propertiesProvider.notifier).createProperty(name, blocks, floors, units);
    
    // UI hala hayattaysa (Ekrandaysa)
    if (mounted) {
       Navigator.of(context).pop(); // Alttan kayan Glassmorphism form ekranını gizle (Kapat)
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.accent, 
            content: Text("🚀 Otonom Portföy Motoru Başarılı! \nToplam ${blocks * floors * units} adet kiralanabilir birim sanal ortama döküldü.")
          )
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mobil Cihazda aşağıdan "Klavye Açıldığında", Form da onunla beraber yukarı Zıplasın diye ölçülendirme
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    final propState = ref.watch(propertiesProvider);
    final isLoading = propState is AsyncLoading; // Riverpod Loading durumundaysa True olur

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // Arkadaki menüyü güzelce devasa bir Flu ile gizler (Cama dönüştürür)
      child: Container(
        margin: EdgeInsets.only(top: AppBar().preferredSize.height + 40),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)), // Üst köşeleri çok keskin oval yuvarlak yapar
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: SingleChildScrollView(
          child: Column(
             mainAxisSize: MainAxisSize.min, // Sadece içindeki itemler kadar uzar
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
                // Klasik Apple Alt Form Tutamacı (Gri Yatay Çizgi)
                Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)))),
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(child: Text("Akıllı Site Oluşturucu", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24))),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Siz sadece ana hatları verin. Uygulama, belirtilen kat ve daire sayısı kadar sanal kapı numarasını otonom yaratacaktır.", style: TextStyle(color: AppColors.textBody, height: 1.4, fontSize: 13)),
                const SizedBox(height: 32),
                
                TextField(
                   controller: _nameController, 
                   style: const TextStyle(color: Colors.white), 
                   decoration: const InputDecoration(labelText: "Emlak/Site Adı (Örn: Boğaz Evleri)")
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                     Expanded(child: TextField(controller: _blocksController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Bloklar", hintText: "1"))),
                     const SizedBox(width: 16),
                     Expanded(child: TextField(controller: _floorsController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Katlar", hintText: "1"))),
                     const SizedBox(width: 16),
                     Expanded(child: TextField(controller: _unitsController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Daire/Kat", hintText: "1"))),
                  ],
                ),
                const SizedBox(height: 40),
                
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading 
                     ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     : const Text("Otonom İnşaata Başla 🚀"),
                ),
                const SizedBox(height: 20),
             ],
          ),
        ),
      ),
    );
  }
}
