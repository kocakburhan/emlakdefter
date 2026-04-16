import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';
import '../providers/support_provider.dart';

class TicketChatBottomSheet extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketChatBottomSheet({Key? key, required this.ticketId}) : super(key: key);

  @override
  ConsumerState<TicketChatBottomSheet> createState() => _TicketChatBottomSheetState();
}

class _TicketChatBottomSheetState extends ConsumerState<TicketChatBottomSheet> {
  final _msgController = TextEditingController();

  void _sendMsg() {
     final text = _msgController.text.trim();
     if (text.isEmpty) return; // Boş atılamaz
     
     // Yazdığım mesajı Otonom Şekilde Riverpod Zekasına ("Yolladım!" diye) aktarırız
     ref.read(supportProvider.notifier).replyToTicket(widget.ticketId, text);
     _msgController.clear(); // Mesaj gidince yazı kutusu silinir.
  }
  
  // Bileti Yeşil Karta Taşı ve Kapat!
  void _closeTicket() {
      ref.read(supportProvider.notifier).closeTicket(widget.ticketId);
      Navigator.of(context).pop(); // Bu Çekmeceyi Kapat (Aşağı it)
  }

  @override
  Widget build(BuildContext context) {
      // iPhone/Klavye yukarı çıktığında Alt menüyü ezmemesi için Klavye inşası Zıplatması
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      final state = ref.watch(supportProvider); // Chat Güncellemelerini Dinler
      
      final ticket = state.value?.firstWhere((e) => e.id == widget.ticketId);
      if (ticket == null) return const SizedBox();

      return BackdropFilter(
         filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // Cam (Glass) Arkaplan Efekti (Blur)
         child: Container(
            margin: EdgeInsets.only(top: AppBar().preferredSize.height), // Çok yukarı çıkıp Notch (Çentik)'i ezmesin
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            decoration: BoxDecoration(
               color: AppColors.background.withValues(alpha:0.9), // Gece karanlığında tatlı Şeffaf arkaplanı
               borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
               border: Border.all(color: Colors.white.withValues(alpha:0.1)) // Tatlı Çerçeve Efekti
            ),
            child: Column(
               mainAxisSize: MainAxisSize.min, // Ekranı klavye açıldıkça gerektiği kadar aşağı doğru itmesi için
               children: [
                  // Sürükleme (Drag) İbresi
                  Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)))),
                  const SizedBox(height: 24),
                  
                  // En Üst Başlık (Kimle Konuşuyorum?)
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Expanded(
                           child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text(ticket.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18), maxLines: 1),
                                 const SizedBox(height: 4),
                                 Text("${ticket.tenantName ?? 'Kiracı'} • ${ticket.location ?? ''}", style: const TextStyle(color: AppColors.textBody, fontSize: 13)),
                              ]
                           )
                        ),
                        if (ticket.status != TicketStatus.resolved)
                           ElevatedButton(
                              onPressed: _closeTicket, 
                              style: ElevatedButton.styleFrom(
                                 backgroundColor: AppColors.success.withValues(alpha:0.2), 
                                 padding: const EdgeInsets.symmetric(horizontal: 16), 
                                 minimumSize: const Size(0,36)
                              ),
                              child: const Text("Bileti Çözüldü Yap", style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold))
                           )
                     ],
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  
                  // WhatsApp Stili Anlık Mesajlaşma (Chat) Yüzeyi
                  Expanded(
                     child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: ticket.messages.length,
                        separatorBuilder: (ctx,idx) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                           final msg = ticket.messages[idx];
                           
                           // Baloncuğu Sağa ya Sola yaslama hesabı
                           return Align(
                              alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                 constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Baloncukların genişliği ekranı kaplamasın! Oranlı dursun
                                 padding: const EdgeInsets.all(14),
                                 decoration: BoxDecoration(
                                    color: msg.isMe ? AppColors.accent.withValues(alpha:0.2) : AppColors.surface, // Ben yolladımsa Camgöbeği/Mavi
                                    borderRadius: BorderRadius.only(
                                       topLeft: const Radius.circular(16),
                                       topRight: const Radius.circular(16),
                                       bottomLeft: msg.isMe ? const Radius.circular(16) : const Radius.circular(4),  // Sola baloncuk sivrisi
                                       bottomRight: msg.isMe ? const Radius.circular(4) : const Radius.circular(16), // Sağa baloncuk sivrisi
                                    ),
                                    border: Border.all(color: msg.isMe ? AppColors.accent.withValues(alpha:0.5) : Colors.white12)
                                 ),
                                 child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       if (!msg.isMe) Text(ticket.tenantName ?? 'Kiracı', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                                       if (!msg.isMe) const SizedBox(height: 4),
                                       Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                       const SizedBox(height: 6),
                                       Align(alignment: Alignment.centerRight, child: Text('${msg.time.hour.toString().padLeft(2,'0')}:${msg.time.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: AppColors.textBody, fontSize: 10))),
                                    ],
                                 )
                              )
                           );
                        }
                     )
                  ),
                  const SizedBox(height: 12),
                  
                  // Metin Yazma & Gönderme Alanı
                  if (ticket.status != TicketStatus.resolved)
                  Row(
                     children: [
                        Expanded(
                           child: TextField(
                              controller: _msgController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                 hintText: "Müşteriye/Kiracıya yanıt verin...",
                                 fillColor: AppColors.surface,
                                 filled: true,
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                              ),
                           )
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                           onTap: _sendMsg,
                           child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                              child: const Icon(Icons.send, color: Colors.white, size: 20),
                           ),
                        )
                     ],
                  )
               ]
            )
         )
      );
  }
}
