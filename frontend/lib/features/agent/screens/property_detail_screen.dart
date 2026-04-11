import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import 'unit_detail_screen.dart';

/// Property Detail Screen - Shows units within a property
class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;

  const PropertyDetailScreen({
    Key? key,
    required this.propertyId,
    required this.propertyName,
  }) : super(key: key);

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  Map<String, dynamic>? _property;
  List<dynamic> _units = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProperty();
  }

  Future<void> _fetchProperty() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.dio.get(
        '/properties/${widget.propertyId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _property = response.data;
          _units = response.data['units'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _occupiedCount => _units.where((u) => u['status'] == 'occupied').length;
  int get _vacantCount => _units.where((u) => u['status'] == 'vacant').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textHeader,
            pinned: true,
            expandedHeight: 100,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.propertyName,
                    style: TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_units.isNotEmpty)
                    Text(
                      '$_occupiedCount Dolu • $_vacantCount Müsait',
                      style: TextStyle(
                        color: AppColors.textBody,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh, size: 20),
                ),
                onPressed: _fetchProperty,
              ),
              const SizedBox(width: 8),
            ],
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Mülk yüklenemedi',
                      style: TextStyle(color: AppColors.textHeader, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _fetchProperty,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            )
          else if (_units.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_outlined, size: 64, color: AppColors.textBody),
                    const SizedBox(height: 16),
                    Text(
                      'Bu mülkte henüz birim yok',
                      style: TextStyle(color: AppColors.textBody, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final unit = _units[index];
                    return _buildUnitCard(unit);
                  },
                  childCount: _units.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> unit) {
    final status = unit['status'] ?? 'vacant';
    final isOccupied = status == 'occupied';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnitDetailScreen(
              propertyId: widget.propertyId,
              unitId: unit['id'],
              propertyName: widget.propertyName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOccupied
                ? AppColors.success.withOpacity(0.3)
                : AppColors.warning.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isOccupied ? AppColors.success : AppColors.warning)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOccupied ? Icons.home : Icons.home_outlined,
                    color: isOccupied ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOccupied ? AppColors.success : AppColors.warning)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOccupied ? 'Dolu' : 'Müsait',
                    style: TextStyle(
                      color: isOccupied ? AppColors.success : AppColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kapı ${unit['door_number'] ?? '-'}',
                  style: TextStyle(
                    color: AppColors.textHeader,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kat ${unit['floor'] ?? '-'}',
                  style: TextStyle(
                    color: AppColors.textBody,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: AppColors.textBody,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${unit['rent_price'] ?? '0'} ₺',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
