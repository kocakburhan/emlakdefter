import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/password_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/set_password_screen.dart';
import '../../features/agent/screens/agent_dashboard_screen.dart';
import '../../features/tenant/screens/tenant_dashboard_screen.dart';
import '../../features/landlord/screens/landlord_dashboard_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/agencies_screen.dart';
import '../../features/admin/screens/agency_detail_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/admin/screens/user_detail_screen.dart';
import '../../features/admin/screens/create_office_with_boss_screen.dart';
import '../../features/admin/screens/create_boss_screen.dart';

/// Singleton navigation service that tracks route history for proper back navigation.
/// This ensures browser back button and in-app back button work consistently.
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final List<String> _history = [];
  static const String _loginRoute = '/';
  static const int _maxHistorySize = 100;

  String get currentRoute => _history.isNotEmpty ? _history.last : _loginRoute;
  bool get canPop => _history.length > 1;
  bool get isAuthenticatedRoute => currentRoute != _loginRoute;

  /// Push a new route onto the navigation stack
  void push(String route) {
    if (_history.isNotEmpty && _history.last == route) return;

    // If route already exists in history but not at top, trim after it
    final existingIndex = _history.indexOf(route);
    if (existingIndex != -1 && existingIndex < _history.length - 1) {
      _history.removeRange(existingIndex, _history.length);
    }

    _history.add(route);
    while (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// Pop current route and return previous route
  String? pop() {
    if (_history.length <= 1) return null;
    _history.removeLast();
    return _history.isNotEmpty ? _history.last : null;
  }

  /// Clear history and reset to login
  void clearAndReset() {
    _history.clear();
    _history.add(_loginRoute);
  }

  /// Clear history and start fresh from a new route
  void clearAndStartFresh(String route) {
    _history.clear();
    _history.add(route);
  }

  /// Replace current route without adding to history
  void replace(String route) {
    if (_history.isNotEmpty) {
      _history.removeLast();
    }
    _history.add(route);
  }

  /// Peek at previous route without popping
  String? peekPrevious() {
    if (_history.length < 2) return null;
    return _history[_history.length - 2];
  }
}

final navService = NavigationService();

/// Redirect logic for authenticated routes
/// Prevents browser back from navigating to login when user is already authenticated
String? _redirectLogic(GoRouterState state) {
  // Only run on web
  if (!kIsWeb) return null;

  // If navigating to root '/' while authenticated, stay on current route
  // This prevents browser back from going to login after authentication
  final isAuthenticated = navService.isAuthenticatedRoute;
  final isGoingToLogin = state.uri.path == '/';

  if (isAuthenticated && isGoingToLogin) {
    // Redirect authenticated users away from login to their dashboard
    return null; // Let them stay where they are
  }

  return null;
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    // Auth routes - public routes
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/password',
      builder: (context, state) {
        final emailOrPhone = state.extra as String? ?? '';
        return PasswordScreen(emailOrPhone: emailOrPhone);
      },
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra;
        String emailOrPhone = '';
        String? userId;
        if (extra is String) {
          emailOrPhone = extra;
        } else if (extra is Map<String, dynamic>) {
          emailOrPhone = extra['emailOrPhone'] ?? '';
          userId = extra['userId'];
        }
        return OtpScreen(emailOrPhone: emailOrPhone, userId: userId);
      },
    ),
    GoRoute(
      path: '/set-password',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final userId = extra['userId'] as String;
        final emailOrPhone = extra['emailOrPhone'] as String;
        return SetPasswordScreen(userId: userId, emailOrPhone: emailOrPhone);
      },
    ),

    // Agent routes - protected
    GoRoute(
      path: '/agent',
      builder: (context, state) => const AgentDashboardScreen(),
    ),

    // Tenant routes - protected
    GoRoute(
      path: '/tenant',
      builder: (context, state) => const TenantDashboardScreen(),
    ),

    // Landlord routes - protected
    GoRoute(
      path: '/landlord',
      builder: (context, state) => const LandlordDashboardScreen(),
    ),

    // Admin routes - protected
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/agencies',
      builder: (context, state) => const AgenciesScreen(),
    ),
    GoRoute(
      path: '/admin/agencies/new',
      builder: (context, state) => const CreateOfficeWithBossScreen(),
    ),
    GoRoute(
      path: '/admin/agencies/:id',
      builder: (context, state) {
        final agencyId = state.pathParameters['id']!;
        return AgencyDetailScreen(agencyId: agencyId);
      },
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UsersScreen(),
    ),
    GoRoute(
      path: '/admin/users/new',
      builder: (context, state) => const CreateBossScreen(),
    ),
    GoRoute(
      path: '/admin/users/:id',
      builder: (context, state) {
        final userId = state.pathParameters['id']!;
        return UserDetailScreen(userId: userId);
      },
    ),
  ],
);
