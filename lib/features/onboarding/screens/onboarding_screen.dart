import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.keyOnboardingComplete, true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _OnboardPage(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.primary,
                    title: 'Welcome to ChargeShield',
                    body:
                        'Automatically detect when you enter London charge zones — CCZ, ULEZ, and LEZ — and get instant alerts so you never miss a payment.',
                  ),
                  _OnboardPage(
                    icon: Icons.location_on_outlined,
                    iconColor: AppColors.lezGreen,
                    title: 'Background GPS Monitoring',
                    body:
                        'ChargeShield runs silently in the background, checking your location. We need location permission (including "always allow") to detect zone entries when the app is closed.',
                  ),
                  _OnboardPage(
                    icon: Icons.notifications_outlined,
                    iconColor: AppColors.ulezOrange,
                    title: 'Smart Payment Reminders',
                    body:
                        'Receive push notifications the moment you enter a zone, plus configurable payment deadline reminders so you avoid late charges.',
                  ),
                ],
              ),
            ),
            // Page dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_page == 1)
                    OutlinedButton.icon(
                      onPressed: _requestLocationPermission,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Grant Location Permission'),
                    ),
                  if (_page == 2)
                    OutlinedButton.icon(
                      onPressed: _requestNotificationPermission,
                      icon: const Icon(Icons.notifications),
                      label: const Text('Enable Notifications'),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == 2 ? 'Get Started' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    // Android requires foreground permission before background
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) {
      await openAppSettings();
      return;
    }

    // Now request background (Always allow)
    final background = await Permission.locationAlways.request();
    if (!mounted) return;

    if (background.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background location permission granted.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please set location to "Allow all the time" in Settings for background tracking.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      await openAppSettings();
    }
  }

  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: iconColor),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade600, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
