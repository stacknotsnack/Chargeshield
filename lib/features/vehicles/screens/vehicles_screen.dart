import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/mot_tax_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/vehicle.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../providers/vehicles_provider.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    final isPremium = ref.watch(subscriptionProvider).isPremium;
    final vehicleLimit = isPremium
        ? AppConstants.proVehicleLimit
        : AppConstants.freeVehicleLimit;
    final atLimit = vehicles.length >= vehicleLimit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: atLimit
            ? () => _showUpgradeDialog(context)
            : () => context.push('/vehicles/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
        backgroundColor: atLimit ? Colors.grey : AppColors.primary,
      ),
      body: vehicles.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No vehicles yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (context, i) =>
                  _VehicleCard(vehicle: vehicles[i]),
            ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Free Tier Limit'),
        content: const Text(
            'The free tier supports 1 vehicle. Upgrade to ChargeShield Pro for up to 10 vehicles.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends ConsumerStatefulWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends ConsumerState<_VehicleCard> {
  DateTime? _motExpiry;
  DateTime? _taxDue;
  bool _loadingDates = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _loadDates() async {
    final mot = await MotTaxService.instance.getMotExpiry(widget.vehicle.registration);
    final tax = await MotTaxService.instance.getTaxDue(widget.vehicle.registration);
    if (!mounted) return;
    setState(() {
      _motExpiry = mot;
      _taxDue = tax;
      _loadingDates = false;
    });
    final isPremium = ref.read(subscriptionProvider).isPremium;
    if (isPremium) {
      final needs = await MotTaxService.instance.needsRefresh(widget.vehicle.registration);
      if (needs && mounted) _refresh(silent: true);
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    if (!silent && mounted) setState(() => _refreshing = true);
    final ok = await MotTaxService.instance.refreshFromDvla(widget.vehicle.registration);
    if (!mounted) return;
    if (ok) {
      final mot = await MotTaxService.instance.getMotExpiry(widget.vehicle.registration);
      final tax = await MotTaxService.instance.getTaxDue(widget.vehicle.registration);
      if (!mounted) return;
      setState(() {
        _motExpiry = mot;
        _taxDue = tax;
        _refreshing = false;
      });
      await NotificationService.instance.scheduleMotTaxReminders(
        registration: widget.vehicle.registration,
        nickname: widget.vehicle.nickname,
        motExpiry: _motExpiry,
        taxDue: _taxDue,
      );
    } else {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Color _dateColor(DateTime? date) {
    if (date == null) return Colors.grey;
    final days = date.difference(DateTime.now()).inDays;
    if (days > 30) return AppColors.safe;
    if (days > 7) return AppColors.warning;
    return AppColors.danger;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Unknown';
    final days = date.difference(DateTime.now()).inDays;
    if (days < 0) return 'Expired ${(-days)}d ago';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in ${days}d';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(subscriptionProvider).isPremium;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.vehicle.nickname,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (widget.vehicle.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(widget.vehicle.registration,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
                if (isPremium)
                  _refreshing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Refresh MOT & Tax dates',
                          onPressed: () => _refresh(),
                        ),
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleAction(context, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit')),
                    if (!widget.vehicle.isDefault)
                      const PopupMenuItem(
                          value: 'default',
                          child: Text('Set as Default')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _InfoChip(
                    label: widget.vehicle.type,
                    icon: Icons.directions_car_outlined),
                _InfoChip(
                    label: widget.vehicle.fuelType,
                    icon: Icons.local_gas_station),
                _InfoChip(
                    label: widget.vehicle.euroStandard,
                    icon: Icons.eco_outlined),
                if (widget.vehicle.isUlezCompliant)
                  const _InfoChip(
                      label: 'ULEZ Compliant',
                      icon: Icons.check_circle_outline,
                      color: AppColors.safe)
                else
                  const _InfoChip(
                      label: 'ULEZ Non-compliant',
                      icon: Icons.cancel_outlined,
                      color: AppColors.danger),
              ],
            ),
            // MOT & Tax section
            if (isPremium) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (_loadingDates)
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading MOT & Tax dates…',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )
              else ...[
                _DateRow(
                  label: 'MOT',
                  date: _motExpiry,
                  color: _dateColor(_motExpiry),
                  tooltip: _dateLabel(_motExpiry),
                  formatted: _motExpiry != null ? _formatDate(_motExpiry!) : null,
                ),
                const SizedBox(height: 4),
                _DateRow(
                  label: 'Road Tax',
                  date: _taxDue,
                  color: _dateColor(_taxDue),
                  tooltip: _dateLabel(_taxDue),
                  formatted: _taxDue != null ? _formatDate(_taxDue!) : null,
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.push('/subscription'),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 14, color: AppColors.premium),
                    const SizedBox(width: 6),
                    const Text(
                      'MOT & Tax reminders — Pro feature',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.premium),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.premium,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'UPGRADE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final notifier = ref.read(vehiclesProvider.notifier);
    if (action == 'edit') {
      context.push('/vehicles/edit', extra: widget.vehicle);
    } else if (action == 'default') {
      await notifier.setDefault(widget.vehicle.id);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Vehicle?'),
          content: Text('Remove ${widget.vehicle.nickname} from ChargeShield?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed == true) {
        await notifier.deleteVehicle(widget.vehicle.id);
      }
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.color,
    required this.tooltip,
    required this.formatted,
  });

  final String label;
  final DateTime? date;
  final Color color;
  final String tooltip;
  final String? formatted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          formatted ?? 'Not recorded',
          style: TextStyle(
              fontSize: 12, color: formatted != null ? color : Colors.grey),
        ),
        if (formatted != null) ...[
          const SizedBox(width: 6),
          Text(
            '($tooltip)',
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.primary;
    return Chip(
      avatar: Icon(icon, size: 14, color: Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: bgColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
