import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import 'dart:math';

enum MatchStatus { pending, matched, rejected }

class TransactionModel {
  final String id;
  final String date;
  final String senderName;
  final double amount;
  final String description;
  final MatchStatus status; // AI'nin bulup çıkardığı eşleşme (Güven) durumu
  final double aiConfidence; // %0-100 arası AI güven skoru (Ne kadar iyi bulduysak o kadar yüksek)

  TransactionModel({
    required this.id,
    required this.date,
    required this.senderName,
    required this.amount,
    required this.description,
    required this.status,
    this.aiConfidence = 100,
  });

  TransactionModel copyWith({MatchStatus? status}) {
    return TransactionModel(
      id: id,
      date: date,
      senderName: senderName,
      amount: amount,
      description: description,
      status: status ?? this.status,
      aiConfidence: aiConfidence,
    );
  }
}

class FinanceNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  FinanceNotifier() : super(const AsyncValue.data([]));
  
  Future<void> uploadBankStatement() async {
     try {
       // 1. Dosya Seçiciyi Aç (Sadece PDF)
       FilePickerResult? result = await FilePicker.platform.pickFiles(
         type: FileType.custom,
         allowedExtensions: ['pdf'],
       );

       if (result == null || (result.files.single.bytes == null && result.files.single.path == null)) {
          // Kullanıcı iptal etti
          return;
       }

       state = const AsyncValue.loading();
       
       final platformFile = result.files.single;
       MultipartFile multipartFile;

       if (platformFile.bytes != null) {
          multipartFile = MultipartFile.fromBytes(platformFile.bytes!, filename: platformFile.name);
       } else {
          multipartFile = await MultipartFile.fromFile(platformFile.path!, filename: platformFile.name);
       }

       FormData formData = FormData.fromMap({
         "file": multipartFile,
       });

       // 2. Gerçek API Çağrısı
       final response = await ApiClient.dio.post('/finance/upload-statement', data: formData);

       // 3. Yanıtı Parse Et
       final matchedResults = response.data['matched_results'] as List<dynamic>;
       
       List<TransactionModel> models = [];
       for (var item in matchedResults) {
          final aiData = item['yapay_zeka_ciktisi'];
          final isMatched = item['is_matched'] as bool;
          final eval = item['payment_evaluation'] as String;
          final score = (item['match_decision_score'] as num).toDouble();
          
          models.add(
            TransactionModel(
              id: item['matched_tenant_id'] ?? "trx_${Random().nextInt(10000)}", 
              date: aiData['date'] ?? "Bilinmiyor", 
              senderName: aiData['sender_name'] ?? "Bilinmiyor",
              amount: double.tryParse(aiData['amount']?.toString() ?? '0') ?? 0.0,
              description: "[AI Analizi]: $eval | Orjinal: ${aiData['description'] ?? ''}",
              status: isMatched ? MatchStatus.matched : MatchStatus.pending,
              aiConfidence: score * 100,
            )
          );
       }

       state = AsyncValue.data(models);

     } catch (e, st) {
       debugPrint("Upload Hatası: $e");
       state = AsyncValue.error(e, st);
     }
  }

  void approveTransaction(String id) {
     if (state.value != null) {
        final list = state.value!;
        final updatedList = list.map((e) {
             if (e.id == id) return e.copyWith(status: MatchStatus.matched);
             return e;
        }).toList();
        state = AsyncValue.data(updatedList);
     }
  }
}

final financeProvider = StateNotifierProvider<FinanceNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  return FinanceNotifier();
});
