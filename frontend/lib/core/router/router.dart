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

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Auth routes
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

    // Agent routes
    GoRoute(
      path: '/agent',
      builder: (context, state) => const AgentDashboardScreen(),
    ),

    // Tenant routes
    GoRoute(
      path: '/tenant',
      builder: (context, state) => const TenantDashboardScreen(),
    ),

    // Landlord routes
    GoRoute(
      path: '/landlord',
      builder: (context, state) => const LandlordDashboardScreen(),
    ),

    // Admin routes
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