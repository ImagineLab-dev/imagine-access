import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_roles.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/tickets/presentation/create_ticket_wizard.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/tickets/presentation/ticket_list_screen.dart';
import '../../features/events/presentation/event_selector_screen.dart';
import '../../features/events/presentation/create_event_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/user_management_screen.dart';
import '../../features/settings/presentation/device_management_screen.dart';
import '../../features/settings/presentation/event_staff_screen.dart';
import '../../features/scanner/presentation/document_search_screen.dart';
import '../../features/dashboard/presentation/stats_screen.dart';
import '../../features/tickets/presentation/ticket_deep_link_screen.dart';
import '../../features/events/presentation/event_deep_link_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(userProvider);
  final role = ref.watch(userRoleProvider);
  final deviceSession = ref.watch(deviceProvider);

  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final isPublicEntry = state.matchedLocation == '/login' ||
          state.matchedLocation == '/welcome';
      final isAuth = user != null || deviceSession != null;

      if (!isAuth && !isPublicEntry) return '/welcome';
      if (isAuth && isPublicEntry) return '/dashboard';

      // Role Guards
      final path = state.matchedLocation;

      // Admin only routes (Sub-settings and Create Event)
      final isAdminRoute = path.startsWith('/settings/users') ||
          path.startsWith('/create_event') ||
          path.startsWith('/settings/devices') ||
          path.startsWith('/event_staff') ||
          path.startsWith('/stats');

      if (isAdminRoute && role != AppRoles.admin) {
        return '/dashboard'; // Redirect non-admins to dashboard
      }

      // Door/Scanner restricted routes
      if (deviceSession != null) {
        // Devices (Door Access) can ONLY see dashboard, scanner and document search
        final allowedForDevice = path == '/dashboard' ||
            path == '/scanner' ||
            path == '/document_search';
        if (!allowedForDevice) return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          final initialTabIndex = mode == 'door' ? 1 : 0;
          return LoginScreen(initialTabIndex: initialTabIndex);
        },
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventSelectorScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/create_ticket',
        builder: (context, state) => const CreateTicketWizard(),
      ),
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/document_search',
        builder: (context, state) => const DocumentSearchScreen(),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const TicketListScreen(),
      ),
      GoRoute(
        path: '/ticket/:ticketId',
        builder: (context, state) => TicketDeepLinkScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/event/:slug',
        builder: (context, state) => EventDeepLinkScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/stats/:eventId',
        builder: (context, state) => StatsScreen(
          eventId: state.pathParameters['eventId']!,
        ),
      ),
      GoRoute(
        path: '/create_event',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateEventScreen(
            eventId: extra?['id'],
            initialData: extra,
          );
        },
      ),
      GoRoute(
        path: '/event_staff',
        builder: (context, state) => const EventStaffScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'users',
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: 'devices',
            builder: (context, state) => const DeviceManagementScreen(),
          ),
        ],
      ),
    ],
  );
});
