import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/employee_service.dart';

/// Employee state
class EmployeeState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> employees;

  EmployeeState({
    this.isLoading = false,
    this.error,
    this.employees = const [],
  });

  EmployeeState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? employees,
  }) {
    return EmployeeState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      employees: employees ?? this.employees,
    );
  }
}

/// Employee notifier
class EmployeeNotifier extends Notifier<EmployeeState> {
  final EmployeeService _service = employeeService;

  @override
  EmployeeState build() => EmployeeState();

  /// Çalışanları yükle
  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final employees = await _service.getEmployees();
      state = state.copyWith(isLoading: false, employees: employees);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Yeni çalışan ekle
  Future<Map<String, dynamic>?> createEmployee({
    String? email,
    String? phoneNumber,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final employee = await _service.createEmployee(
        email: email,
        phoneNumber: phoneNumber,
        fullName: fullName,
      );
      final updatedEmployees = [...state.employees, employee];
      state = state.copyWith(isLoading: false, employees: updatedEmployees);
      return employee;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Çalışan pasife al
  Future<bool> deactivateEmployee(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.deactivateEmployee(userId);
      final updatedEmployees = state.employees.map((e) {
        if (e['id'] == userId) {
          return {...e, 'status': 'inactive'};
        }
        return e;
      }).toList();
      state = state.copyWith(isLoading: false, employees: updatedEmployees);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Çalışan sil
  Future<bool> deleteEmployee(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.deleteEmployee(userId);
      final updatedEmployees = state.employees.where((e) => e['id'] != userId).toList();
      state = state.copyWith(isLoading: false, employees: updatedEmployees);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Hata temizle
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final employeeProvider = NotifierProvider<EmployeeNotifier, EmployeeState>(() {
  return EmployeeNotifier();
});