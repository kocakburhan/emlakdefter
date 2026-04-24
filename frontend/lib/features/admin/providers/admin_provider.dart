import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/admin_service.dart';

/// Admin panel durumu
class AdminState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> agencies;
  final List<Map<String, dynamic>> users;
  final Map<String, dynamic>? selectedAgency;
  final Map<String, dynamic>? selectedUser;

  AdminState({
    this.isLoading = false,
    this.error,
    this.agencies = const [],
    this.users = const [],
    this.selectedAgency,
    this.selectedUser,
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? agencies,
    List<Map<String, dynamic>>? users,
    Map<String, dynamic>? selectedAgency,
    Map<String, dynamic>? selectedUser,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      agencies: agencies ?? this.agencies,
      users: users ?? this.users,
      selectedAgency: selectedAgency ?? this.selectedAgency,
      selectedUser: selectedUser ?? this.selectedUser,
    );
  }
}

/// Admin provider
class AdminNotifier extends Notifier<AdminState> {
  final AdminService _service = adminService;

  @override
  AdminState build() => AdminState();

  /// Ofisleri yükle
  Future<void> loadAgencies() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final agencies = await _service.getAgencies();
      state = state.copyWith(isLoading: false, agencies: agencies);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Yeni ofis oluştur
  Future<Map<String, dynamic>?> createAgency({
    required String name,
    required String address,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final agency = await _service.createAgency(name: name, address: address);
      final updatedAgencies = [...state.agencies, agency];
      state = state.copyWith(isLoading: false, agencies: updatedAgencies);
      return agency;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Yeni ofis ve patron oluştur
  Future<Map<String, dynamic>?> createAgencyWithBoss({
    required String agencyName,
    required String agencyAddress,
    required String bossFullName,
    String? bossEmail,
    String? bossPhone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final agency = await _service.createAgencyWithBoss(
        agencyName: agencyName,
        agencyAddress: agencyAddress,
        bossFullName: bossFullName,
        bossEmail: bossEmail,
        bossPhone: bossPhone,
      );
      final updatedAgencies = [...state.agencies, agency];
      state = state.copyWith(isLoading: false, agencies: updatedAgencies);
      return agency;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Ofis sil
  Future<bool> deleteAgency(String agencyId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.deleteAgency(agencyId);
      final updatedAgencies = state.agencies
          .where((a) => a['id'] != agencyId)
          .toList();
      state = state.copyWith(isLoading: false, agencies: updatedAgencies);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Kullanıcıları yükle
  Future<void> loadUsers({String? role, String? agencyId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final users = await _service.getUsers(role: role, agencyId: agencyId);
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Patron/çalışan oluştur
  Future<Map<String, dynamic>?> createUser({
    String? email,
    String? phoneNumber,
    required String fullName,
    required String role,
    String? agencyId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _service.createUser(
        email: email,
        phoneNumber: phoneNumber,
        fullName: fullName,
        role: role,
        agencyId: agencyId,
      );
      final updatedUsers = [...state.users, user];
      state = state.copyWith(isLoading: false, users: updatedUsers);
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Kullanıcı pasife al
  Future<bool> deactivateUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.deactivateUser(userId);
      final updatedUsers = state.users.map((u) {
        if (u['id'] == userId) {
          return {...u, 'status': 'inactive'};
        }
        return u;
      }).toList();
      state = state.copyWith(isLoading: false, users: updatedUsers);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Kullanıcı sil
  Future<bool> deleteUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.deleteUser(userId);
      final updatedUsers = state.users.where((u) => u['id'] != userId).toList();
      state = state.copyWith(isLoading: false, users: updatedUsers);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Seçili ofisi ayarla
  void setSelectedAgency(Map<String, dynamic>? agency) {
    state = state.copyWith(selectedAgency: agency);
  }

  /// Seçili kullanıcıyı ayarla
  void setSelectedUser(Map<String, dynamic>? user) {
    state = state.copyWith(selectedUser: user);
  }

  /// Hata temizle
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final adminProvider = NotifierProvider<AdminNotifier, AdminState>(() {
  return AdminNotifier();
});