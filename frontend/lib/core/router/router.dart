import 'package:go_router/go_router.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/email_login_screen.dart';
import '../../features/agent/screens/agent_dashboard_screen.dart';
import '../../features/tenant/screens/tenant_dashboard_screen.dart';
import '../../features/landlord/screens/landlord_dashboard_screen.dart';

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
        return EmailLoginScreen(role: role);
      },
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'tenant';
        final token = state.uri.queryParameters['t'];
        return EmailLoginScreen(role: role, invitationToken: token);
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