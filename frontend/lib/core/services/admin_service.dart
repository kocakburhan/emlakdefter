import '../../core/network/api_client.dart';

/// Admin API servisi
class AdminService {
  /// Tüm ofisleri listele
  Future<List<Map<String, dynamic>>> getAgencies() async {
    final response = await ApiClient.dio.get('/v1/admin/agencies');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  /// Yeni ofis oluştur
  Future<Map<String, dynamic>> createAgency({
    required String name,
    required String address,
  }) async {
    final response = await ApiClient.dio.post(
      '/v1/admin/agencies',
      data: {'agency_name': name, 'agency_address': address},
    );
    return response.data;
  }

  /// Yeni ofis ve patron oluştur
  Future<Map<String, dynamic>> createAgencyWithBoss({
    required String agencyName,
    required String agencyAddress,
    required String bossFullName,
    String? bossEmail,
    String? bossPhone,
  }) async {
    final response = await ApiClient.dio.post(
      '/v1/admin/agencies',
      data: {
        'agency_name': agencyName,
        'agency_address': agencyAddress,
        'boss_full_name': bossFullName,
        if (bossEmail != null && bossEmail.isNotEmpty) 'boss_email': bossEmail,
        if (bossPhone != null && bossPhone.isNotEmpty) 'boss_phone_number': bossPhone,
      },
    );
    return response.data;
  }

  /// Ofis güncelle
  Future<Map<String, dynamic>> updateAgency({
    required String agencyId,
    String? name,
    String? address,
  }) async {
    final response = await ApiClient.dio.put(
      '/v1/admin/agencies/$agencyId',
      data: {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
      },
    );
    return response.data;
  }

  /// Ofis sil
  Future<void> deleteAgency(String agencyId) async {
    await ApiClient.dio.delete('/v1/admin/agencies/$agencyId');
  }

  /// Tüm kullanıcıları listele
  Future<List<Map<String, dynamic>>> getUsers({String? role, String? agencyId}) async {
    final params = <String, dynamic>{};
    if (role != null) params['role'] = role;
    if (agencyId != null) params['agency_id'] = agencyId;

    final response = await ApiClient.dio.get(
      '/v1/admin/users',
      queryParameters: params,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  /// Patron oluştur
  Future<Map<String, dynamic>> createUser({
    String? email,
    String? phoneNumber,
    required String fullName,
    required String role,
    String? agencyId,
  }) async {
    final response = await ApiClient.dio.post(
      '/v1/admin/users',
      data: {
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'full_name': fullName,
        'role': role,
        if (agencyId != null) 'agency_id': agencyId,
      },
    );
    return response.data;
  }

  /// Kullanıcı güncelle
  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? email,
    String? phoneNumber,
    String? fullName,
    String? status,
  }) async {
    final response = await ApiClient.dio.put(
      '/v1/admin/users/$userId',
      data: {
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (fullName != null) 'full_name': fullName,
        if (status != null) 'status': status,
      },
    );
    return response.data;
  }

  /// Kullanıcı sil
  Future<void> deleteUser(String userId) async {
    await ApiClient.dio.delete('/v1/admin/users/$userId');
  }

  /// Kullanıcı pasife al
  Future<void> deactivateUser(String userId) async {
    await ApiClient.dio.post('/v1/admin/users/$userId/deactivate');
  }

  /// Ofise bağlı kullanıcıları listele
  Future<List<Map<String, dynamic>>> getAgencyUsers(String agencyId) async {
    final response = await ApiClient.dio.get('/v1/admin/agencies/$agencyId/users');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }
}

final adminService = AdminService();