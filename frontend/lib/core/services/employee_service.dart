import '../../../core/network/api_client.dart';

/// Employee API servisi (Patron çalışan ekleme için)
class EmployeeService {
  /// Ofisteki çalışanları listele
  Future<List<Map<String, dynamic>>> getEmployees() async {
    final response = await ApiClient.dio.get('/agency/employees');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  /// Yeni çalışan ekle
  Future<Map<String, dynamic>> createEmployee({
    String? email,
    String? phoneNumber,
    required String fullName,
    String? password,
  }) async {
    final response = await ApiClient.dio.post(
      '/agency/employees',
      data: {
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'full_name': fullName,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    return response.data;
  }

  /// Çalışan güncelle
  Future<Map<String, dynamic>> updateEmployee({
    required String userId,
    String? email,
    String? phoneNumber,
    String? fullName,
  }) async {
    final response = await ApiClient.dio.put(
      '/agency/employees/$userId',
      data: {
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (fullName != null) 'full_name': fullName,
      },
    );
    return response.data;
  }

  /// Çalışan pasife al
  Future<void> deactivateEmployee(String userId) async {
    await ApiClient.dio.post('/agency/employees/$userId/deactivate');
  }

  /// Çalışan sil
  Future<void> deleteEmployee(String userId) async {
    await ApiClient.dio.delete('/agency/employees/$userId');
  }
}

final employeeService = EmployeeService();
