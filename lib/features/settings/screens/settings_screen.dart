import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/zone_polygons.dart';
import '../../../core/providers/zone_prefs_provider.dart';
import '../../../core/services/background_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../history/providers/history_provider.dart';
import '../../subscription/providers/subscription_provider.dart';

// Record exact route toggle — Pro only, stored in SharedPreferences so
// the background isolate can read it without needing Hive.
final _recordRouteProvider =
    StateNotifierProvider<_RecordRouteNotifier, bool>(
        (_) => _RecordRouteNotifier());

class _RecordRouteNotifier extends StateNotifier<bool> {
  _RecordRouteNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(AppConstants.keyRecordExactRoute) ?? false;
  }

  Future<void> toggle(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyRecordExactRoute, v);
    state = v;
  }
}

// Mock GPS mode lives in SharedPreferences (readable from background isolate).
final _mockGpsProvider = StateNotifierProvider<_MockGpsNotifier, bool>(
    (_) => _MockGpsNotifier());

class _MockGpsNotifier extends StateNotifier<bool> {
  _MockGpsNotifier() : super(false) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(AppConstants.keyMockGpsMode) ?? false;
  }

  Future<void> toggle(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyMockGpsMode, v);
    state = v;
  }
}

final _settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
    (ref) => SettingsNotifier());

class SettingsState {
  const SettingsState({
    this.notificationsEnabled = true,
    this.paymentRemindersEnabled = true,
    this.reminderMinutesBefore = 60,
  });

  final bool notificationsEnabled;
  final bool paymentRemindersEnabled;
  final int reminderMinutesBefore;

  SettingsState copyWith({
    bool? notificationsEnabled,
    bool? paymentRemindersEnabled,
    int? reminderMinutesBefore,
  }) =>
      SettingsState(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        paymentRemindersEnabled:
            paymentRemindersEnabled ?? this.paymentRemindersEnabled,
        reminderMinutesBefore:
            reminderMinutesBefore ?? this.reminderMinutesBefore,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Box get _box => Hive.box(AppConstants.settingsBox);

  void _load() {
    state = SettingsState(
      notificationsEnabled:
          _box.get(AppConstants.keyNotificationsEnabled, defaultValue: true)
              as bool,
      paymentRemindersEnabled:
          _box.get(AppConstants.keyPaymentRemindersEnabled, defaultValue: true)
              as bool,
      reminderMinutesBefore:
          _box.get(AppConstants.keyReminderMinutesBefore, defaultValue: 60)
              as int,
    );
  }

  Future<void> setNotifications(bool v) async {
    await _box.put(AppConstants.keyNotificationsEnabled, v);
    state = state.copyWith(notificationsEnabled: v);
  }

  Future<void> setPaymentReminders(bool v) async {
    await _box.put(AppConstants.keyPaymentRemindersEnabled, v);
    state = state.copyWith(paymentRemindersEnabled: v);
  }

  Future<void> setReminderMinutes(int v) async {
    await _box.put(AppConstants.keyReminderMinutesBefore, v);
    state = state.copyWith(reminderMinutesBefore: v);
  }
}

/// Region definitions for accordion display.
class _RegionDef {
  const _RegionDef({
    required this.name,
    required this.color,
    required this.zones,
    this.defaultExpanded = false,
  });
  final String name;
  final Color color;
  final List<ZoneInfo> zones;
  final bool defaultExpanded;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static final _regions = [
    _RegionDef(
      name: 'London',
      color: Colors.red,
      zones: LondonZones.all,
      defaultExpanded: true,
    ),
    _RegionDef(
      name: 'Midlands',
      color: AppColors.primary,
      zones: [UkZones.birmingham, UkZones.m6TollNorth, UkZones.m6TollSouth],
    ),
    _RegionDef(
      name: 'South West',
      color: AppColors.primary,
      zones: [UkZones.bath],
    ),
    _RegionDef(
      name: 'South',
      color: AppColors.primary,
      zones: [UkZones.portsmouth],
    ),
    _RegionDef(
      name: 'North',
      color: AppColors.primary,
      zones: [UkZones.bradford, UkZones.sheffield],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(_settingsProvider);
    final notifier = ref.read(_settingsProvider.notifier);
    final mockGps = ref.watch(_mockGpsProvider);
    final zoneNotifs = ref.watch(zoneNotifsProvider);
    final zoneDisplay = ref.watch(zoneDisplayProvider);
    final isPremium = ref.watch(subscriptionProvider).isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        children: [
          // Notifications
          const _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Zone Entry Alerts'),
            subtitle: const Text('Notify when entering a charge zone'),
            value: settings.notificationsEnabled,
            onChanged: notifier.setNotifications,
            activeColor: AppColors.primary,
          ),
          // Per-zone accordion — shown when master notifications are on
          if (settings.notificationsEnabled) ...[
            // Select all / Deselect all
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.check_box_outlined, size: 16),
                    label: const Text('Select all', style: TextStyle(fontSize: 12)),
                    onPressed: () => _setAll(ref, zoneNotifs, true, isPremium),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.check_box_outline_blank, size: 16),
                    label: const Text('Deselect all', style: TextStyle(fontSize: 12)),
                    onPressed: () => _setAll(ref, zoneNotifs, false, isPremium),
                  ),
                ],
              ),
            ),
            // Region accordions
            for (final region in _regions)
              _RegionAccordion(
                region: region,
                zoneNotifs: zoneNotifs,
                zoneDisplay: zoneDisplay,
                isPremium: isPremium,
              ),
          ],
          SwitchListTile(
            title: const Text('Payment Reminders'),
            subtitle: const Text('Remind you before payment deadline'),
            value: settings.paymentRemindersEnabled,
            onChanged: settings.notificationsEnabled
                ? notifier.setPaymentReminders
                : null,
            activeColor: AppColors.primary,
          ),
          if (settings.paymentRemindersEnabled)
            ListTile(
              title: const Text('Reminder Time'),
              subtitle: Text(
                  '${settings.reminderMinutesBefore} minutes before deadline'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickReminderTime(context, ref, settings),
            ),

          const Divider(),
          const _SectionHeader('Journey Tracking'),
          _RecordRouteToggle(),

          const Divider(),
          const _SectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.workspace_premium, color: AppColors.premium),
            title: const Text('Manage Subscription'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/subscription'),
          ),

          const Divider(),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('Clear Journey History'),
            onTap: () => _clearHistory(context),
          ),

          // Debug section — only visible in debug builds
          if (kDebugMode) ...[
            const Divider(),
            const _SectionHeader('Debug'),
            SwitchListTile(
              title: const Text('Mock GPS Mode'),
              subtitle: const Text(
                'Enables Fake Route / mock GPS apps. '
                'Automatically restarts tracking when toggled.',
              ),
              value: mockGps,
              onChanged: (v) => _toggleMockGps(context, ref, v),
              activeColor: Colors.orange,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined,
                  color: Colors.orange),
              title: const Text('Fire Test Notification'),
              subtitle: const Text(
                  'Sends a fake Dartford zone entry alert to verify notifications work.'),
              onTap: () => _fireTestNotification(context),
            ),
            Consumer(builder: (context, ref, _) {
              final isPremium = ref.watch(isPremiumProvider);
              return SwitchListTile(
                secondary: const Icon(Icons.workspace_premium, color: Colors.orange),
                title: const Text('Simulate Pro'),
                subtitle: const Text('Grants Pro access without payment. Debug only.'),
                value: isPremium,
                onChanged: (v) async {
                  await Hive.box(AppConstants.settingsBox)
                      .put(AppConstants.keyPremiumActive, v);
                  ref.read(isPremiumProvider.notifier).state = v;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(v ? 'Pro enabled.' : 'Pro disabled.'),
                      duration: const Duration(seconds: 2),
                    ));
                  }
                },
                activeColor: Colors.orange,
              );
            }),
          ],

          const Divider(),
          const _SectionHeader('Legal'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/privacy'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            trailing: Text('v1.3', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _setAll(WidgetRef ref, Map<String, bool> zoneNotifs, bool value, bool isPremium) {
    final notifsNotifier = ref.read(zoneNotifsProvider.notifier);
    for (final region in _regions) {
      for (final zone in region.zones) {
        if (zone.comingSoon) continue;
        final locked = zone.proOnly
            ? !isPremium
            : !AppConstants.freeAlertZoneIds.contains(zone.id) && !isPremium;
        if (!locked || !value) {
          notifsNotifier.setZone(zone.id, value);
        }
      }
    }
  }

  /// Toggles mock GPS mode and auto-restarts the background service so the
  /// new setting takes effect immediately without the user having to manually
  /// stop and start tracking.
  Future<void> _toggleMockGps(BuildContext context, WidgetRef ref, bool v) async {
    await ref.read(_mockGpsProvider.notifier).toggle(v);
    final running = await BackgroundLocationService.isRunning();
    if (running) {
      await BackgroundLocationService.stop();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await BackgroundLocationService.start();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(v
                ? 'Mock GPS mode ON — tracking restarted. Start Fake Route now.'
                : 'Mock GPS mode OFF — tracking restarted for real GPS.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(v
                ? 'Mock GPS mode ON. Enable tracking then start Fake Route.'
                : 'Mock GPS mode OFF.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Fires a real local notification for Dartford to confirm the notification
  /// pipeline is working end-to-end, independent of GPS.
  Future<void> _fireTestNotification(BuildContext context) async {
    try {
      await NotificationService.instance.notifyZoneEntries(
        [LondonZones.dartford],
        'TEST-REG',
        vehicleType: 'car',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent — check your notification bar.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification failed: $e')),
        );
      }
    }
  }

  void _pickReminderTime(
      BuildContext context, WidgetRef ref, SettingsState settings) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Remind me how early?'),
        children: [30, 60, 120, 180]
            .map(
              (mins) => SimpleDialogOption(
                onPressed: () {
                  ref.read(_settingsProvider.notifier).setReminderMinutes(mins);
                  Navigator.pop(context);
                },
                child: Text(
                  mins < 60 ? '$mins minutes' : '${mins ~/ 60} hour(s)',
                  style: TextStyle(
                    fontWeight: settings.reminderMinutesBefore == mins
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear History?'),
        content:
            const Text('This will delete all journey history. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // delete all
    }
  }
}

// ---------------------------------------------------------------------------
// Region accordion
// ---------------------------------------------------------------------------

class _RegionAccordion extends ConsumerWidget {
  const _RegionAccordion({
    required this.region,
    required this.zoneNotifs,
    required this.zoneDisplay,
    required this.isPremium,
  });

  final _RegionDef region;
  final Map<String, bool> zoneNotifs;
  final Map<String, bool> zoneDisplay;
  final bool isPremium;

  bool _isLocked(ZoneInfo zone) {
    if (zone.proOnly) return !isPremium;
    return !AppConstants.freeAlertZoneIds.contains(zone.id) && !isPremium;
  }

  bool get _allEnabled {
    final toggleable = region.zones.where((z) => !z.comingSoon && !_isLocked(z));
    if (toggleable.isEmpty) return false;
    return toggleable.every((z) => zoneNotifs[z.id] ?? true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeZones = region.zones.where((z) => !z.comingSoon).toList();
    final isProRegion = region.zones.every((z) => z.proOnly || z.comingSoon);

    return Theme(
      // Remove ExpansionTile's default divider lines
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: region.defaultExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: region.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              region.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (isProRegion) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.premium,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('PRO',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
            const Spacer(),
            // Master toggle — enable/disable all in region
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: _allEnabled,
                onChanged: isPremium || !isProRegion
                    ? (v) {
                        final notifsNotifier =
                            ref.read(zoneNotifsProvider.notifier);
                        for (final zone in activeZones) {
                          if (!_isLocked(zone) || !v) {
                            notifsNotifier.setZone(zone.id, v);
                          }
                        }
                      }
                    : null,
                activeColor: AppColors.primary,
              ),
            ),
          ],
        ),
        children: region.zones.map((zone) {
          return _ZonePreferenceTile(
            zone: zone,
            notifyOn: zoneNotifs[zone.id] ?? true,
            displayOn: zoneDisplay[zone.id] ?? true,
            onNotifyChanged: (v) =>
                ref.read(zoneNotifsProvider.notifier).setZone(zone.id, v),
            onDisplayChanged: (v) =>
                ref.read(zoneDisplayProvider.notifier).setZone(zone.id, v),
            notifyLocked: _isLocked(zone),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zone preference tile
// ---------------------------------------------------------------------------

class _ZonePreferenceTile extends StatelessWidget {
  const _ZonePreferenceTile({
    required this.zone,
    required this.notifyOn,
    required this.displayOn,
    required this.onNotifyChanged,
    required this.onDisplayChanged,
    required this.notifyLocked,
  });

  final ZoneInfo zone;
  final bool notifyOn;
  final bool displayOn;
  final ValueChanged<bool> onNotifyChanged;
  final ValueChanged<bool> onDisplayChanged;

  /// When true the Notify checkbox is greyed out and forced off.
  /// The Show-on-card checkbox is always editable regardless.
  final bool notifyLocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone header row
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 2),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(zone.color),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${zone.shortName} – ${zone.name}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (notifyLocked) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_outline,
                      size: 13, color: AppColors.premium),
                  const SizedBox(width: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.premium,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          // Notify + Show on card checkboxes
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: notifyLocked ? 0.4 : 1.0,
                  child: CheckboxListTile(
                    dense: true,
                    title: const Text('Notify',
                        style: TextStyle(fontSize: 13)),
                    secondary: const Icon(Icons.notifications_outlined,
                        size: 18),
                    value: notifyLocked ? false : notifyOn,
                    onChanged: notifyLocked
                        ? null
                        : (v) => onNotifyChanged(v ?? notifyOn),
                    activeColor: AppColors.primary,
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  dense: true,
                  title: const Text('Show on card',
                      style: TextStyle(fontSize: 13)),
                  secondary:
                      const Icon(Icons.visibility_outlined, size: 18),
                  value: displayOn,
                  onChanged: (v) => onDisplayChanged(v ?? displayOn),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneGroupHeader extends StatelessWidget {
  const _ZoneGroupHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 16, 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RecordRouteToggle extends ConsumerWidget {
  const _RecordRouteToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final recordRoute = ref.watch(_recordRouteProvider);

    return SwitchListTile(
      title: Row(
        children: [
          const Text('Record Exact Route'),
          if (!isPremium) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.premium,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('PRO',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        isPremium
            ? 'Store your GPS path through charge zones for detailed journey view.'
            : 'Upgrade to Pro to record your exact route.',
        style: TextStyle(
            color: isPremium ? null : Colors.grey.shade500),
      ),
      value: isPremium ? recordRoute : false,
      onChanged: isPremium
          ? (v) => ref.read(_recordRouteProvider.notifier).toggle(v)
          : null,
      activeColor: AppColors.primary,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

