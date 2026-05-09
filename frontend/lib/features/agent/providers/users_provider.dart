import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Represents a user (employee, tenant, or landlord)
class AppUser {
  final String id;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String role; // 'employee' | 'tenant' | 'landlord'
  final String status;
  final String? propertyName;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    this.email,
    this.phoneNumber,
    required this.role,
    required this.status,
    this.propertyName,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json, String role) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? json['temp_name'] ?? 'Unknown',
      email: json['email'],
      phoneNumber: json['phone_number'] ?? json['temp_phone'],
      role: role,
      status: json['status'] ?? 'active',
      propertyName: json['property_name'] ?? json['unit_door'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Which user category is currently selected
enum UserCategory { employees, tenants, landlords }

/// Users state
class UsersState {
  final List<AppUser> employees;
  final List<AppUser> tenants;
  final List<AppUser> landlords;
  final UserCategory selectedCategory;
  final bool isLoading;
  final String? error;

  const UsersState({
    this.employees = const [],
    this.tenants = const [],
    this.landlords = const [],
    this.selectedCategory = UserCategory.employees,
    this.isLoading = false,
    this.error,
  });

  List<AppUser> get currentUsers {
    switch (selectedCategory) {
      case UserCategory.employees:
        return employees;
      case UserCategory.tenants:
        return tenants;
      case UserCategory.landlords:
        return landlords;
    }
  }

  UsersState copyWith({
    List<AppUser>? employees,
    List<AppUser>? tenants,
    List<AppUser>? landlords,
    UserCategory? selectedCategory,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return UsersState(
      employees: employees ?? this.employees,
      tenants: tenants ?? this.tenants,
      landlords: landlords ?? this.landlords,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Users notifier — manages all 3 user types
class UsersNotifier extends Notifier<UsersState> {
  @override
  UsersState build() => const UsersState();

  /// Select a category and load its users
  Future<void> selectCategory(UserCategory category) async {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category, clearError: true);

    switch (category) {
      case UserCategory.employees:
        if (state.employees.isEmpty) await loadEmployees();
        break;
      case UserCategory.tenants:
        if (state.tenants.isEmpty) await loadTenants();
        break;
      case UserCategory.landlords:
        if (state.landlords.isEmpty) await loadLandlords();
        break;
    }
  }

  /// Load employees
  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiClient.dio.get('/agency/employees');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final employees = data.map((e) => AppUser.fromJson(e, 'employee')).toList();
        state = state.copyWith(isLoading: false, employees: employees);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load tenants
  Future<void> loadTenants() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiClient.dio.get('/tenants', queryParameters: {'limit': 200});
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final tenants = data.map((e) => AppUser.fromJson(e, 'tenant')).toList();
        state = state.copyWith(isLoading: false, tenants: tenants);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load landlords
  Future<void> loadLandlords() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiClient.dio.get('/tenants/landlords', queryParameters: {'limit': 200});
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final landlords = data.map((e) => AppUser.fromJson(e, 'landlord')).toList();
        state = state.copyWith(isLoading: false, landlords: landlords);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load all categories (for initial load)
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.wait([
      _loadEmployeesInternal(),
      _loadTenantsInternal(),
      _loadLandlordsInternal(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadEmployeesInternal() async {
    try {
      final response = await ApiClient.dio.get('/agency/employees');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final employees = data.map((e) => AppUser.fromJson(e, 'employee')).toList();
        state = state.copyWith(employees: employees);
      }
    } catch (_) {}
  }

  Future<void> _loadTenantsInternal() async {
    try {
      final response = await ApiClient.dio.get('/tenants', queryParameters: {'limit': 200});
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final tenants = data.map((e) => AppUser.fromJson(e, 'tenant')).toList();
        state = state.copyWith(tenants: tenants);
      }
    } catch (_) {}
  }

  Future<void> _loadLandlordsInternal() async {
    try {
      final response = await ApiClient.dio.get('/tenants/landlords', queryParameters: {'limit': 200});
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final landlords = data.map((e) => AppUser.fromJson(e, 'landlord')).toList();
        state = state.copyWith(landlords: landlords);
      }
    } catch (_) {}
  }
}

final usersProvider = NotifierProvider<UsersNotifier, UsersState>(() {
  return UsersNotifier();
});