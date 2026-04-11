import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/properties_provider.dart';
import '../widgets/create_property_bottom_sheet.dart';
import '../screens/property_detail_screen.dart';

class PropertiesTab extends ConsumerWidget {
  const PropertiesTab({Key? key}) : super(key: key);

  // Fab'a (.yani kocaman + (Ekle) Butonuna) basılınca açılacak Otonom Form Çekmecesi Mimari Çağrısı
  void _showCreateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,           // Form klavye çıktığında ekran boyunu geçerse diye...
      backgroundColor: Colors.transparent, // Çekmecenin ana köşeli yapısını bozmamak için içi Saydam çizilir.
      builder: (ctx) => const CreatePropertyBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod'daki State Kutusunu (Bina listesini) izler. Guncellendikçe UI da reaktif güncellenir.
    final propertiesState = ref.watch(propertiesProvider);

    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("Portföyünüz", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
                         const SizedBox(height: 4),
                         Text("Binalar ve Siteler", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                       ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Bina Kartlarının Döngüyle Çizimi (Loading / Boş / Veritabanı) Durumları dahil
                propertiesState.when(
                  loading: () => const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
                  error: (err, stack) => Expanded(child: Center(child: Text("Hata: $err", style: const TextStyle(color: AppColors.error)))),
                  data: (list) {
                    if (list.isEmpty) {
                       // Hiç bina yoksa, hayalet ikon cizimi.
                       return Expanded(
                         child: Center(
                            child: Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                  const Icon(Icons.business_outlined, size: 64, color: AppColors.textBody),
                                  const SizedBox(height: 16),
                                  Text("Henüz portföyünüzde mülk yok.", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textBody)),
                               ]
                            )
                         )
                       );
                    }
                    
                    return Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: list.length + 1, // Ekstra 1: "Yeni Liste (Aşağıdaki + )" butonunun altına inmesini sağlar!
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
                        itemBuilder: (ctx, idx) {
                           if (idx == list.length) return const SizedBox(height: 120);
                           final prop = list[idx];
                           return _buildPropertyCard(context, prop);
                        },
                      ),
                    );
                  }
                )
              ],
            ),
          ),
          
          // Ufak (+) Butonu! "Floating Action Button" ile otonom sistemi tetikler:
          Positioned(
            bottom: 110, // Menü BottomNavigationBar'ın Altına düşmemesi için Float Button çok hafif Göklerde uçurulur!
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: () => _showCreateBottomSheet(context),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 8,
              icon: const Icon(Icons.add_business),
              label: const Text("Yeni Ekle", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // Özel Tasarımlı (Kapsül biçiminde % Oranlı) Bina Kartımız İçin Flutter Widget Parçalama Tasarımı:
  Widget _buildPropertyCard(BuildContext context, PropertyModel prop) {
     final double occupancyRate = ((prop.totalUnits - prop.emptyUnits) / prop.totalUnits) * 100;

     return GestureDetector(
       onTap: () {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => PropertyDetailScreen(
               propertyId: prop.id,
               propertyName: prop.name,
             ),
           ),
         );
       },
       child: Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
       ),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                      children: [
                         Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.business, color: AppColors.accent, size: 24),
                         ),
                         const SizedBox(width: 14),
                         Text(prop.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                      ],
                   ),
                   const Icon(Icons.chevron_right, color: AppColors.textBody),
                ],
             ),
             const SizedBox(height: 20),
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildStat(context, "Toplam", "${prop.totalUnits} Kapı", AppColors.textHeader),
                   _buildStat(context, "Müsait", "${prop.emptyUnits} Boş", AppColors.warning),
                   _buildStat(context, "Doluluk", "%${occupancyRate.toStringAsFixed(0)}", AppColors.success),
                ]
             ),
             const SizedBox(height: 16),
             ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                   value: occupancyRate / 100,
                   backgroundColor: Colors.white.withOpacity(0.05),
                   color: AppColors.success,
                   minHeight: 6,
                ),
             )
          ],
       ),
     ),
     );
  }

  // Bina kartı içindeki ufak '3 Kapı, 5 Boş vs' yazan istatistik sütunları (Kapsüller):
  Widget _buildStat(BuildContext context, String label, String value, Color color) {
     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, color: color)),
           const SizedBox(height: 4),
           Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textBody)),
        ],
     );
  }
}
