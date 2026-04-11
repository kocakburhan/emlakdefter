import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../agent/providers/support_provider.dart'; 
// Şimdilik Kiracı (B2C) arayüzünde "Aynı veritabanından veri akıyormuş hissiyatını" simüle etmek 
// için Lort (Yetkili) panelinin veritabanını ödünç okuttuk! Mükemmel senkronizasyon!

class TenantSupportTab extends ConsumerWidget {
  const TenantSupportTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Emlakçının Canlı (Backend) Destek Panosunu Dinleyen Kulak (Göz)
    final state = ref.watch(supportProvider);

    return SafeArea(
      child: Stack(
         children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text("Zarar ve Arızalar İçin Yönetimle Doğrudan", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("İletişim Kurun", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                  const SizedBox(height: 32),
                  
                  Expanded(
                     child: state.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                        error: (e, st) => Center(child: Text("Hata: $e")),
                        data: (list) {
                           if (list.isEmpty) return const Center(child: Text("Süper! Sistemde açtığınız hiçbir destek veya arıza kaydı yok."));
                           
                           return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: list.length + 1,
                              separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
                              itemBuilder: (ctx, idx) {
                                 // FAB butonun altına liste girip sıkışmasın diye ekstra margin payı (Kör Kutu)
                                 if (idx == list.length) return const SizedBox(height: 120);
                                 final ticket = list[idx];
                                 return _buildTenantTicketCard(context, ticket);
                              }
                           );
                        }
                     )
                  )
                ],
              ),
            ),
            
            // "Kombim Patladı, Daireyi Su Bastı!" Diye Müşterinin Çığlık Atacağı Yeni Bilet Tuşu
            Positioned(
               bottom: 110,
               right: 24,
               child: FloatingActionButton.extended(
                  onPressed: () {
                     // TODO: Kiracı B2C Bilet Oluşturma Alt Çekmecesi (BottomSheet)
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppColors.error, content: Text("Acil Yardım Kaydı Formu (WhatsApp Chat'i) Açılıyor...")));
                  },
                  backgroundColor: AppColors.error, // Tüketiciye anında tepki verdiğimizi belirten Güçlü Kırmızı renk.
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_alert_rounded),
                  label: const Text("Talebiniz Var Mı?", style: TextStyle(fontWeight: FontWeight.bold)),
               )
            )
         ],
      ),
    );
  }

  Widget _buildTenantTicketCard(BuildContext context, TicketModel ticket) {
     Color getStatusColor() {
        if (ticket.status == TicketStatus.resolved) return AppColors.success;
        if (ticket.status == TicketStatus.open) return AppColors.error;
        return AppColors.warning;
     }
     
     final sColor = getStatusColor();

     return InkWell(
        onTap: () {
           // Kiracı tıklarsa Tüketici (B2C) Sohbet Paneli açılacak (Sağda Ben, Solda Emlakçı Lort)
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu bilete ait sohbet paneli yükleniyor...")));
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
           padding: const EdgeInsets.all(20),
           decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              // Eğer yeşilse çok soluk çerçeve, Uyarı bekliyorsa ışıl ışıl Glow çerçeve
              border: Border.all(color: sColor.withOpacity(0.4), width: ticket.status == TicketStatus.resolved ? 0.5 : 1.5),
           ),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       // Talebin Durumu (Etiketi)
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: sColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                             ticket.status == TicketStatus.resolved ? "Sorun Çözüldü" : (ticket.status == TicketStatus.open ? "Lort Müdahalesi Bekleniyor (Acil)" : "Yanıt Bekleniyor"),
                             style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.bold)
                          )
                       ),
                       const Icon(Icons.chevron_right, color: AppColors.textBody)
                    ]
                 ),
                 const SizedBox(height: 16),
                 Text(ticket.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18), maxLines: 1),
                 const SizedBox(height: 8),
                 // Alt kısmında Chat'lerdeki "En Son kim ne dedi?" (Last Message Oku) Önizlemesi
                 Text("En son mesaj: \"${ticket.messages.last.text}\"", style: const TextStyle(color: AppColors.textBody, fontSize: 13, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]
           )
        )
     );
  }
}
