import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/history/screens/journey_detail_screen.dart';
import '../../data/models/journey.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/subscription/screens/subscription_screen.dart';
import '../../data/models/vehicle.dart';
import '../../features/vehicles/screens/add_vehicle_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';
import '../../features/legal/screens/legal_webview_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: _initialRoute(),
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/map',
      builder: (_, __) => const MapScreen(),
    ),
    GoRoute(
      path: '/vehicles',
      builder: (_, __) => const VehiclesScreen(),
    ),
    GoRoute(
      path: '/vehicles/add',
      builder: (_, __) => const AddVehicleScreen(),
    ),
    GoRoute(
      path: '/vehicles/edit',
      builder: (_, state) => AddVehicleScreen(vehicle: state.extra as Vehicle),
    ),
    GoRoute(
      path: '/history',
      builder: (_, __) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/history/:id',
      builder: (context, state) => JourneyDetailScreen(
        journey: state.extra as Journey,
      ),
    ),
    GoRoute(
      path: '/subscription',
      builder: (_, __) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/legal/terms',
      builder: (_, __) => const LegalWebViewScreen(
        title: 'Terms of Service',
        url: 'https://chargeshield.co.uk/terms.html',
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      builder: (_, __) => const LegalWebViewScreen(
        title: 'Privacy Policy',
        url: 'https://chargeshield.co.uk/privacy.html',
      ),
    ),
  ],
);

String _initialRoute() {
  try {
    final box = Hive.box(AppConstants.settingsBox);
    final onboarded =
        box.get(AppConstants.keyOnboardingComplete, defaultValue: false) as bool;
    return onboarded ? '/home' : '/onboarding';
  } catch (_) {
    return '/onboarding';
  }
}
