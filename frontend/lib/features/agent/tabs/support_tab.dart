import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/support_provider.dart';
import '../widgets/ticket_chat_bottom_sheet.dart';

class SupportTab extends ConsumerWidget {
  const SupportTab({Key? key}) : super(key: key);

  // Karta Basılınca Alt Tabandan Fırlayacak Chat (WhatsApp Tarzı) Panel Çağrısı
  void _openChat(BuildContext context, TicketModel ticket) {
     showModalBottomSheet(
       context: context,
       isScrollControlled: true, // Klavye açıldı mı kendini iter!
       backgroundColor: Colors.transparent, // Form köşeleri yumusak kalsın diye cam saydamlığı burada verildi.
       builder: (ctx) => TicketChatBottomSheet(ticketId: ticket.id),
     );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ekrana veri akıtan ve durumu kontrol eden ana göbek izleyicimiz:
    final state = ref.watch(supportProvider);
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             const SizedBox(height: 24),
             Text("Kiracılar ve Talepler", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
             const SizedBox(height: 4),
             Text("Destek Paneli", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
             const SizedBox(height: 24),

             Expanded(
                child: state.when(
                   loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                   error: (e, st) => Center(child: Text("Hata: $e")),
                   data: (list) {
                     // Hiçbir arıza ve şikayet yoksa.
                     if (list.isEmpty) return const Center(child: Text("Harika! Hiçbir şikayet/bilet açılmamış, her şey yolunda!", style: TextStyle(color: AppColors.success)));

                     // Lort'ların gözünden Kaçmaması gereken en Acil mesajların En Tepeye Fışkırtılarak (Kırmızı Kırmızı) dizilmesi zekası!
                     final sorted = List<TicketModel>.from(list)..sort((a,b) {
                        if (a.status == TicketStatus.open && b.status != TicketStatus.open) return -1;
                        if (a.status != TicketStatus.open && b.status == TicketStatus.open) return 1;
                        if (a.status == TicketStatus.inProgress && b.status == TicketStatus.resolved) return -1;
                        if (a.status == TicketStatus.resolved && b.status == TicketStatus.inProgress) return 1;
                        return 0;
                     });

                     return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: sorted.length + 1, // +1 eklenir ki Alt Nav Bara binen kartlar sıkışmasın!
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
                        itemBuilder: (ctx, idx) {
                           if (idx == sorted.length) return const SizedBox(height: 100);
                           return _buildTicketCard(context, sorted[idx]);
                        },
                     );
                   }
                )
             )
          ]
        )
      )
    );
  }

  // Renkli, Yuvarlak Çerçeveli Bilet / Şikayet Kart Cizeri
  Widget _buildTicketCard(BuildContext context, TicketModel ticket) {
      Color cardColor;
      IconData statIcon;
      // Zekadan gelen ticket durumuna (Acil/Bekleme vs) Renk ve İkon Kodlaması yapıyoruz
      switch(ticket.status) {
         case TicketStatus.open: cardColor = AppColors.error; statIcon = Icons.warning_rounded; break;
         case TicketStatus.inProgress: cardColor = AppColors.warning; statIcon = Icons.hourglass_top_rounded; break;
         case TicketStatus.resolved: cardColor = AppColors.success; statIcon = Icons.check_circle_rounded; break;
         case TicketStatus.closed: cardColor = AppColors.textBody; statIcon = Icons.check_circle_outline_rounded; break;
      }

      return InkWell(
         onTap: () => _openChat(context, ticket),
         borderRadius: BorderRadius.circular(20),
         child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
               color: AppColors.surface.withOpacity(0.5),
               borderRadius: BorderRadius.circular(20),
               // Kırmızı Alarmda borderslar daha kalın ve koyu! Oraya Bas! demesi için.
               border: Border.all(color: cardColor.withOpacity(0.4), width: ticket.status == TicketStatus.open ? 1.5 : 1.0),
            ),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Row(
                     children: [
                        Icon(statIcon, color: cardColor, size: 24),
                        const SizedBox(width: 12),
                        // Taşmalı Şikayet Başlıkları
                        Expanded(child: Text(ticket.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.chevron_right, color: AppColors.textBody)
                     ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Row(
                           children: [
                              const Icon(Icons.person, color: AppColors.textBody, size: 16),
                              const SizedBox(width: 6),
                              Text(ticket.tenantName ?? 'Kiracı', style: const TextStyle(color: AppColors.textBody, fontSize: 13)),
                           ],
                        ),
                        // Kiracının Konumu (Dairesi)
                        Text(ticket.location ?? '', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                     ],
                  )
               ],
            ),
         ),
      );
  }
}
