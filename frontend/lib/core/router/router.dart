import 'package:go_router/go_router.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/phone_login_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/agent/screens/agent_dashboard_screen.dart';
import '../../features/tenant/screens/tenant_dashboard_screen.dart'; // Phase 8 Added

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
        final role = state.uri.queryParameters['role'] ?? 'tenant';
        return PhoneLoginScreen(role: role);
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
      path: '/agent-dashboard',
      builder: (context, state) => const AgentDashboardScreen(),
    ),
    GoRoute(
      path: '/tenant-dashboard',
      builder: (context, state) => const TenantDashboardScreen(),
    ),
  ],
);
