import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// PDF Taranması (Gemini 2.5) sürecini Mobile uyarlayan Mock (Sahte) akıl yöneticisi.
class FinanceNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  FinanceNotifier() : super(const AsyncValue.data([])); // Başlangıçta PDF olmadığı için liste boş!
  
  // "Banka Ekstresi Yükle" botonuna basılınca çalışan fonk.
  Future<void> uploadBankStatement() async {
     state = const AsyncValue.loading();
     try {
       // Gemini AI ve PDF işleme süresi (3 Saniyelik 'Wow Effect' animasyon beklemesi)
       await Future.delayed(const Duration(seconds: 3));
       
       // Sahte Finans Dekont Satırları: Biri tam uymuş(Yeşil), diğeri İsim Eşleşmemiş(Sarı)
       final dummyData = [
         TransactionModel(
           id: "trx_1", date: "2026-04-01", senderName: "Ahmet Yılmaz", 
           amount: 17500.0, description: "Ağaoğlu B1 D:4 Kira Bedeli", 
           status: MatchStatus.matched, aiConfidence: 98.5
         ),
         TransactionModel(
           id: "trx_2", date: "2026-04-02", senderName: "Mehmet Çınar", 
           amount: 1450.0, description: "TR54B Aidat ödemesi Mehmet Ç.", 
           status: MatchStatus.matched, aiConfidence: 95.0
         ),
         TransactionModel(
           id: "trx_3", date: "2026-04-03", senderName: "GİZEM KAYA", // AI şüphelendi: Sistemde o daire "Selin Kaya" üstüne
           amount: 15000.0, description: "KİRA GÖNDERİM", 
           status: MatchStatus.pending, aiConfidence: 65.0
         ),
       ];
       
       state = AsyncValue.data(dummyData);
     } catch (e, st) {
       state = AsyncValue.error(e, st);
     }
  }

  // Sarı kartları (Bekleyen AI şüphelilerini) Manuel olarak Lort (Emlakçı) ONAYLDığında çalışan sistem:
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
