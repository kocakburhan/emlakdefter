import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/api_client.dart';

/// Backend'deki Property tablosunun Flutter karşılığı (DTO/Model)
class PropertyModel {
  final String id;
  final String name;
  final String type;
  final String? address;
  final int totalUnits;
  final int centralDues;
  final Map<String, dynamic>? features;
  final DateTime? createdAt;

  // Hesaplanan alan (Backend'den gelmiyor, unit listesinden hesaplanacak)
  final int emptyUnits;

  PropertyModel({
    required this.id,
    required this.name,
    this.type = 'building',
    this.address,
    required this.totalUnits,
    this.centralDues = 0,
    this.features,
    this.createdAt,
    this.emptyUnits = 0,
  });

  /// Backend JSON → Flutter Model
  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'building',
      address: json['address'],
      totalUnits: json['total_units'] ?? 0,
      centralDues: json['central_dues'] ?? 0,
      features: json['features'] != null 
          ? Map<String, dynamic>.from(json['features']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      emptyUnits: 0, // İleride unit detayından hesaplanacak
    );
  }
}

/// Binaların (Property) gerçek API'den çekildiği Asenkron Durum Yöneticisi
class PropertiesNotifier extends StateNotifier<AsyncValue<List<PropertyModel>>> {
  PropertiesNotifier() : super(const AsyncValue.loading()) {
    fetchProperties();
  }

  /// Backend'den portföy listesini çeker: GET /api/v1/properties
  Future<void> fetchProperties() async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient.dio.get('/properties');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final properties = data
            .map((json) => PropertyModel.fromJson(json))
            .toList();
        state = AsyncValue.data(properties);
        debugPrint("🏢 ${properties.length} mülk başarıyla yüklendi.");
      } else {
        throw Exception("API yanıt kodu: ${response.statusCode}");
      }
    } catch (e, st) {
      debugPrint("⚠️ Mülk listesi yüklenemedi: $e");
      // API hatası durumunda boş liste göster (uygulama çökmesin)
      state = AsyncValue.error(e, st);
    }
  }

  /// Yeni apartman/mülk oluşturur: POST /api/v1/properties
  /// PRD Madde 4.1.2-B: Otonom Üretim Motoru tetiklenir
  Future<bool> createProperty({
    required String name,
    required String type,
    String? address,
    int centralDues = 0,
    Map<String, dynamic>? features,
    // Otonom Generative Parameters (Apartman/Site için)
    int? startFloor,
    int? endFloor,
    int? unitsPerFloor,
  }) async {
    final currentList = state.value ?? [];
    
    try {
      final response = await ApiClient.dio.post('/properties', data: {
        'name': name,
        'type': type,
        'address': address,
        'central_dues': centralDues,
        'features': features ?? {},
        'start_floor': startFloor,
        'end_floor': endFloor,
        'units_per_floor': unitsPerFloor,
      });

      if (response.statusCode == 201 && response.data != null) {
        final newProp = PropertyModel.fromJson(response.data);
        state = AsyncValue.data([...currentList, newProp]);
        debugPrint("✅ Yeni mülk oluşturuldu: ${newProp.name} (${newProp.totalUnits} birim)");
        return true;
      } else {
        throw Exception("Mülk oluşturma başarısız: ${response.statusCode}");
      }
    } catch (e, st) {
      debugPrint("⚠️ Mülk oluşturma hatası: $e");
      state = AsyncValue.data(currentList); // Listeyi geri yükle
      return false;
    }
  }

  /// Listeyi yenile (pull-to-refresh için)
  Future<void> refresh() async {
    await fetchProperties();
  }
}

final propertiesProvider = StateNotifierProvider<PropertiesNotifier, AsyncValue<List<PropertyModel>>>((ref) {
  return PropertiesNotifier();
});
