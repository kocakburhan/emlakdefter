import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TicketStatus { critical, pending, resolved }

class ChatMessage {
  final String text;
  final bool isMe; // Emlakçı/Agent (Ben) mi gönderdim?
  final String time;

  ChatMessage({required this.text, required this.isMe, required this.time});
}

class TicketModel {
  final String id;
  final String title;
  final String tenantName;
  final String location; // Örn: Yıldız Sitesi B1/4
  final TicketStatus status;
  final List<ChatMessage> messages;

  TicketModel({
    required this.id,
    required this.title,
    required this.tenantName,
    required this.location,
    required this.status,
    required this.messages,
  });

  TicketModel copyWith({TicketStatus? status, List<ChatMessage>? messages}) {
     return TicketModel(
       id: id,
       title: title,
       tenantName: tenantName,
       location: location,
       status: status ?? this.status,
       messages: messages ?? this.messages,
     );
  }
}

// Biletlerimizi (Destek Kutusunu) ve Kiracı Sohbetlerini tutan Riverpod Hafızası
class SupportNotifier extends StateNotifier<AsyncValue<List<TicketModel>>> {
  SupportNotifier() : super(const AsyncValue.loading()) {
    _fetchTickets();
  }

  // İlk açılışta veritabanından Canlı Şikayetlerin İnmesi (Mock)
  Future<void> _fetchTickets() async {
    state = const AsyncValue.loading();
    try {
       await Future.delayed(const Duration(seconds: 1)); // Ağ Gecikmesi Animasyonu
       final data = [
         TicketModel(
           id: "tk1", title: "Acil: Kombiden Su Akıyor!", tenantName: "Ahmet Yılmaz", location: "Ağaoğlu My World D/4", status: TicketStatus.critical, 
           messages: [
              ChatMessage(text: "Merhabalar iyi akşamlar, Daire 4 kombisinden alttaki daireye su damlıyor. Acil asistanlık ve usta gönderimi rica ediyorum!", isMe: false, time: "10:24"),
           ]
         ),
         TicketModel(
           id: "tk2", title: "Aidat Ödemesi Ulaşmadı mı?", tenantName: "Gizem Kaya", location: "İstMarina B2 D/12", status: TicketStatus.pending, 
           messages: [
              ChatMessage(text: "Bu ayki faturayı IBAN üzerinden gönderdim. Makbuzumu uygulamaya atmayı unutmuşum, sisteme bakar mısınız düşmüş mü diye?", isMe: false, time: "Dün 14:30"),
           ]
         ),
         TicketModel(
           id: "tk3", title: "Asansör Gürültü Problemi", tenantName: "Mehmet Çınar", location: "Yıldız Apt. Kat: 3", status: TicketStatus.resolved, 
           messages: [
              ChatMessage(text: "Gece saatlerinde asansör askı kablosu çok yoğun sürtünme sesi yapıyor.", isMe: false, time: "Çrş 09:00"),
              ChatMessage(text: "Teknik ekibe derhal bildirdim Mehmet Bey, bugün yağlama yapacaklar.", isMe: true, time: "Çrş 09:12"),
              ChatMessage(text: "Asansörcü ustalar geldi, problem tamamen çözüldü teşekkürler.", isMe: false, time: "Çrş 16:40"),
           ]
         ),
       ];
       state = AsyncValue.data(data);
    } catch(e, st) {
       state = AsyncValue.error(e, st);
    }
  }

  // Riverpod üzerinden arayüzde Chat "Gönder" kısmına basıldığında mesajı arkaplana ekler.
  void replyToTicket(String ticketId, String messageText) {
     if (state.value != null) {
        final list = state.value!;
        final nwList = list.map((e) {
           if (e.id == ticketId) {
               // Benim Gönderdiğim Mesajı Obje Olarak Ekle
               final newMsg = ChatMessage(text: messageText, isMe: true, time: "Şimdi");
               final newMessages = [...e.messages, newMsg];
               
               // Eğer kritikse /pending yapma. Normal beklemeysependingde dursun.
               final newStatus = (e.status == TicketStatus.resolved) ? TicketStatus.pending : e.status; 
               return e.copyWith(messages: newMessages, status: newStatus); 
           }
           return e;
        }).toList();
        state = AsyncValue.data(nwList);
     }
  }
  
  // Emlakçı Konuyu Tatlıya Bağladığında, "Çözüldü Olarak İşaretle" Butonu
  void closeTicket(String ticketId) {
     if (state.value != null) {
        state = AsyncValue.data(state.value!.map((e) => e.id == ticketId ? e.copyWith(status: TicketStatus.resolved) : e).toList());
     }
  }
}

final supportProvider = StateNotifierProvider<SupportNotifier, AsyncValue<List<TicketModel>>>((ref) => SupportNotifier());
