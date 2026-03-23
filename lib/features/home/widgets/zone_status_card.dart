import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/zone_polygons.dart';
import '../../../core/services/zone_detection_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/vehicle.dart';

class ZoneStatusCard extends StatelessWidget {
  const ZoneStatusCard({
    super.key,
    this.status,
    this.vehicle,
    this.hiddenZoneIds = const {},
  });

  final ZoneStatus? status;
  final Vehicle? vehicle;
  /// Zone IDs the user has opted to hide from this card (e.g. {'lez'}).
  final Set<String> hiddenZoneIds;

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.location_searching, color: Colors.grey),
              const SizedBox(width: 12),
              Text('Waiting for location...',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final activeZones = status!.activeZones
        .where((z) => !hiddenZoneIds.contains(z.id))
        .toList();
    final isInZone = activeZones.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isInZone ? AppColors.danger : AppColors.safe,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInZone ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: isInZone ? AppColors.danger : AppColors.safe,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isInZone
                        ? 'In Charge Zone${activeZones.length > 1 ? 's' : ''}'
                        : 'No Charge Zone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isInZone ? AppColors.danger : AppColors.safe,
                    ),
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(status!.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),

            if (activeZones.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...activeZones.map((zone) => _ZoneRow(zone: zone, vehicle: vehicle)),
            ],

            if (!isInZone && vehicle != null) ...[
              const SizedBox(height: 8),
              Text(
                '${vehicle!.registration} is outside all charge zones.',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone, this.vehicle});

  final ZoneInfo zone;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final vehicleType = vehicle?.type ?? 'car';
    final charge = zone.chargeFor(vehicleType);
    final isExempt = vehicle != null && _isExempt(zone, vehicle!, charge);
    final suffix = zone.isCrossing ? '/crossing' : '/day';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(zone.color),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              zone.shortName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              zone.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (isExempt)
            const Chip(
              label: Text('EXEMPT', style: TextStyle(fontSize: 10)),
              backgroundColor: AppColors.safe,
              labelStyle: TextStyle(color: Colors.white),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            )
          else if (charge == 0.0)
            const Chip(
              label: Text('FREE', style: TextStyle(fontSize: 10)),
              backgroundColor: AppColors.safe,
              labelStyle: TextStyle(color: Colors.white),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            )
          else
            Text(
              '£${charge.toStringAsFixed(2)}$suffix',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.danger),
            ),
        ],
      ),
    );
  }

  bool _isExempt(ZoneInfo zone, Vehicle vehicle, double charge) {
    if (charge == 0.0) return false; // shown as FREE, not EXEMPT
    if (zone.id == 'ccz') return vehicle.isCczExempt;
    if (zone.id == 'ulez') return vehicle.isUlezCompliant;
    return false;
  }
}
