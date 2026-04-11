import 'package:go_router/go_router.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/simple_login_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/agent/screens/agent_dashboard_screen.dart';
import '../../features/tenant/screens/tenant_dashboard_screen.dart';
import '../../features/landlord/screens/landlord_dashboard_screen.dart';

/// Otonom Gezinme Rotası (İleride Riverpod interceptorleri ve JWT bazlı zorlayıcı Guard rotalar buraya eklenecektir.)
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'agent';
        return SimpleLoginScreen(role: role);
      },
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'tenant';
        final phone = state.uri.queryParameters['phone'] ?? '';
        return OtpVerificationScreen(role: role, phone: phone);
      },
    ),
    GoRoute(
      path: '/agent',
      builder: (context, state) => const AgentDashboardScreen(),
    ),
    GoRoute(
      path: '/tenant',
      builder: (context, state) => const TenantDashboardScreen(),
    ),
    GoRoute(
      path: '/landlord',
      builder: (context, state) => const LandlordDashboardScreen(),
    ),
  ],
);
