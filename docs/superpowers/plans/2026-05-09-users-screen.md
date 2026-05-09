# Kullanıcılar Ekranı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `EmployeesTab` with a new animated "Users" screen that shows 3 category cards (Çalışanlar, Kiracılar, Ev Sahipleri). Tapping a card animates and expands to show a list filtered by category.

**Architecture:** Replace `employees_tab.dart` with a new `users_tab.dart` containing a `UsersScreen` widget. Three animated category cards at the top, each card has on-tap expansion animation revealing the relevant user list. Backend endpoints already exist (employees, tenants, landlords), just need a new unified provider and service layer.

**Tech Stack:** Flutter Riverpod (NotifierProvider), Dio, flutter_animate, `TweenAnimationBuilder`

---

## File Structure

```
frontend/
├── lib/features/agent/
│   ├── tabs/
│   │   ├── employees_tab.dart           → DELETE (replaced)
│   │   └── users_tab.dart              → CREATE (new unified screen)
│   ├── screens/
│   │   └── agent_dashboard_screen.dart → MODIFY (line 39: EmployeesTab → UsersTab)
│   ├── providers/
│   │   ├── employees_provider.dart     → MODIFY (rename → users_provider.dart, expand to support all 3 types)
│   │   └── users_provider.dart          → CREATE (new combined users state provider)
│   └── services/
│       ├── employee_service.dart       → MODIFY (add tenant/landlord methods)
│       └── user_service.dart           → CREATE (unified service combining employees/tenants/landlords)

backend/
├── app/api/endpoints/
│   ├── agency.py        → Already has /agency/employees endpoints ✅
│   └── tenants.py      → Already has /tenants and /tenants/landlords ✅ (no changes needed)
```

---

### Task 1: Create `users_provider.dart` with combined state for all 3 user types

**Files:**
- Create: `frontend/lib/features/agent/providers/users_provider.dart`

```dart
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
```

- [ ] **Step 1: Create `frontend/lib/features/agent/providers/users_provider.dart`**
- [ ] **Step 2: Run flutter analyze to verify no errors**

---

### Task 2: Create `users_tab.dart` with animated card selection UI

**Files:**
- Create: `frontend/lib/features/agent/tabs/users_tab.dart`

**Key Design:**
- 3 animated category cards: "Çalışanlar" (person icon), "Kiracılar" (home icon), "Ev Sahipleri" (account_balance icon)
- Cards use `TweenAnimationBuilder<double>` for scale/opacity animations
- On card tap: selected card scales up slightly with a glow effect, unselected cards fade/scale down
- User list appears below cards with `AnimatedSwitcher` + fade-in
- Each user card shows avatar, name, email/phone, status badge

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/users_provider.dart';

/// Kullanıcılar Ekranı — Animated card selection for employees/tenants/landlords
class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({Key? key}) : super(key: key);

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersProvider);
    final notifier = ref.read(usersProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        title: const Text('Kullanıcılar'),
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.charcoal))
          : Column(
              children: [
                // Animated category cards
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      _buildCategoryCard(
                        context,
                        category: UserCategory.employees,
                        label: 'Çalışanlar',
                        icon: Icons.person,
                        count: state.employees.length,
                        color: AppColors.charcoal,
                        isSelected: state.selectedCategory == UserCategory.employees,
                        onTap: () => notifier.selectCategory(UserCategory.employees),
                      ),
                      const SizedBox(width: 12),
                      _buildCategoryCard(
                        context,
                        category: UserCategory.tenants,
                        label: 'Kiracılar',
                        icon: Icons.home,
                        count: state.tenants.length,
                        color: AppColors.success,
                        isSelected: state.selectedCategory == UserCategory.tenants,
                        onTap: () => notifier.selectCategory(UserCategory.tenants),
                      ),
                      const SizedBox(width: 12),
                      _buildCategoryCard(
                        context,
                        category: UserCategory.landlords,
                        label: 'Ev Sahipleri',
                        icon: Icons.account_balance,
                        count: state.landlords.length,
                        color: AppColors.warning,
                        isSelected: state.selectedCategory == UserCategory.landlords,
                        onTap: () => notifier.selectCategory(UserCategory.landlords),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Category label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _getCategoryLabel(state.selectedCategory),
                      const Spacer(),
                      Text(
                        '${state.currentUsers.length} kullanıcı',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // User list
                Expanded(
                  child: state.currentUsers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          itemCount: state.currentUsers.length,
                          itemBuilder: (context, index) {
                            final user = state.currentUsers[index];
                            return _buildUserCard(user, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required UserCategory category,
    required String label,
    required IconData icon,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: isSelected ? 1.05 : 0.95),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: isSelected ? 1.0 : 0.6),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, _) {
                return Opacity(
                  opacity: 0.4 + (opacity * 0.6),
                  child: child,
                );
              },
            ),
          );
        },
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [color.withValues(alpha: 0.9), color.withValues(alpha: 0.7)]
                    : [color.withValues(alpha: 0.15), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(
              children: [
                Icon(icon, color: isSelected ? Colors.white : color, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(AppUser user, int index) {
    final statusColor = user.status == 'active' ? AppColors.success : AppColors.textSecondary;
    final statusLabel = user.status == 'active' ? 'Aktif' : 'Pasif';
    final roleColor = user.role == 'employee'
        ? AppColors.charcoal
        : user.role == 'tenant'
            ? AppColors.success
            : AppColors.warning;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 40).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 15 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor.withValues(alpha: 0.8), roleColor.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: const TextStyle(
                            color: AppColors.charcoal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.propertyName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.propertyName!,
                            style: const TextStyle(
                              color: AppColors.charcoal,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (user.email != null && user.email!.isNotEmpty)
                        Expanded(
                          child: Text(
                            user.email!,
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                        Expanded(
                          child: Text(
                            user.phoneNumber!,
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Bu kategoride kullanıcı yok',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCategoryLabel(UserCategory category) {
    switch (category) {
      case UserCategory.employees:
        return const Text(
          'Çalışanlar',
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      case UserCategory.tenants:
        return const Text(
          'Kiracılar',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      case UserCategory.landlords:
        return const Text(
          'Ev Sahipleri',
          style: TextStyle(
            color: AppColors.warning,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
    }
  }
}
```

- [ ] **Step 1: Create `frontend/lib/features/agent/tabs/users_tab.dart`**
- [ ] **Step 2: Run flutter analyze to verify no errors**

---

### Task 3: Update `agent_dashboard_screen.dart` to use UsersTab instead of EmployeesTab

**Files:**
- Modify: `frontend/lib/features/agent/screens/agent_dashboard_screen.dart:15` (import) and `frontend/lib/features/agent/screens/agent_dashboard_screen.dart:39` (tab reference)

```dart
// Change import
import '../tabs/employees_tab.dart';
// to
import '../tabs/users_tab.dart';
```

```dart
// Change in _pages list
const EmployeesTab(),
// to
const UsersTab(),
```

- [ ] **Step 1: Modify import and tab reference in `agent_dashboard_screen.dart`**
- [ ] **Step 2: Run flutter analyze to verify no errors**

---

### Task 4: Update project_status.md

**Files:**
- Modify: `project_status.md` — add entry under "Tamamlanan Görevler"

```
### 9 Mayıs 2026 — Kullanıcılar Ekranı (Animated Card Selection)

**Yapılan Değişiklikler:**

1. **Yeni Kullanıcılar Ekranı** (`frontend/lib/features/agent/tabs/users_tab.dart`):
   - 3 kategori kartı: Çalışanlar, Kiracılar, Ev Sahipleri
   - TweenAnimationBuilder ile animasyonlu kart seçimi
   - Seçili kart scale + opacity artışı, seçili olmayanlar fade out
   - Her kartta kullanıcı sayısı rozeti
   - AnimatedSwitcher ile kategori değişim animasyonu

2. **Yeni Users Provider** (`frontend/lib/features/agent/providers/users_provider.dart`):
   - AppUser model: tüm kullanıcı tiplerini birleştirir
   - UsersNotifier: employees/tenants/landlords ayrı listeler
   - UserCategory enum ile seçili kategori takibi
   - loadAll(): tüm kategorileri paralel yükler

3. **Agent Dashboard Güncellemesi** (`agent_dashboard_screen.dart`):
   - EmployeesTab → UsersTab (tab index 5)
   - 7. tab = Users (formerly Employees)

**Backend:** Değişiklik yok — mevcut endpoint'ler kullanıldı (`/agency/employees`, `/tenants`, `/tenants/landlords`)

**Durum:** Tamamlandı ✅
```

- [ ] **Step 1: Update `project_status.md`**

---

### Task 5: Commit changes

- [ ] **Step 1: Commit**

```bash
cd D:/Projects/EmlakDefteri
git add frontend/lib/features/agent/tabs/users_tab.dart \
       frontend/lib/features/agent/providers/users_provider.dart \
       frontend/lib/features/agent/screens/agent_dashboard_screen.dart \
       project_status.md
git commit -m "feat(frontend): new animated Users screen with 3-category card selection

- UsersTab replaces EmployeesTab with animated category cards
- TweenAnimationBuilder for scale/opacity card selection
- 3 categories: Employees, Tenants, Landlords
- UsersNotifier manages all user types from existing endpoints
- Backend unchanged (uses existing /agency/employees, /tenants, /tenants/landlords)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Summary

| Task | Action | Files |
|------|--------|-------|
| 1 | Create users provider | `users_provider.dart` |
| 2 | Create animated users tab | `users_tab.dart` |
| 3 | Update dashboard | `agent_dashboard_screen.dart` |
| 4 | Update project status | `project_status.md` |
| 5 | Commit | — |

**Plan complete and saved to `docs/superpowers/plans/2026-05-09-users-screen.md`**

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?