import 'package:flutter_riverpod/flutter_riverpod.dart';

// Kiracının Ana Bilgileri (Hangi dairede oturuyor vs)
class TenantInfo {
  final String name;
  final String propertyName;
  final String unitNumber;
  final double currentDebt;
  final String dueDate;

  TenantInfo({
    required this.name,
    required this.propertyName,
    required this.unitNumber,
    required this.currentDebt,
    required this.dueDate,
  });
}

// Kiracı (B2C) arayüzündeki Borç/Borçluluk durumunu ve kimlik bilgisini ekrana (Mock/Sahte) basan Zeka
class TenantNotifier extends StateNotifier<AsyncValue<TenantInfo>> {
  TenantNotifier() : super(const AsyncValue.loading()) {
    _fetchTenantData();
  }

  Future<void> _fetchTenantData() async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(seconds: 2)); // Sahte Yükleme Efekti (Wow)
      
      // Kiracı Gizem Hanım sisteme girmiş gibi simülasyon yaratalım
      final dummyTenant = TenantInfo(
         name: "Gizem Kaya",
         propertyName: "İstMarina B2 Blok",
         unitNumber: "Daire: 12",
         currentDebt: 17500.0, // Borcu var
         dueDate: "15 Nisan 2026",
      );

      state = AsyncValue.data(dummyTenant);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Aidat/Kira "Ödendi" Dekontu simülasyonu (Borcu sıfırlama büyüsü)
  Future<void> payDebtMock() async {
     if (state.value != null) {
        state = const AsyncValue.loading(); // Tekrar Spinner başlasın
        await Future.delayed(const Duration(seconds: 2));
        
        final paidTenant = TenantInfo(
           name: state.value!.name,
           propertyName: state.value!.propertyName,
           unitNumber: state.value!.unitNumber,
           currentDebt: 0.0, // BORÇ SIFIRLANDI!
           dueDate: "Önümüzdeki Ay",
        );
        state = AsyncValue.data(paidTenant);
     }
  }
}

final tenantProvider = StateNotifierProvider<TenantNotifier, AsyncValue<TenantInfo>>((ref) {
  return TenantNotifier();
});
