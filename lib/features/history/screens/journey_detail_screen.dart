import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/journey.dart';
import '../../../data/repositories/journey_repository.dart';
import '../../history/providers/history_provider.dart';
import '../../vehicles/providers/vehicles_provider.dart';

class JourneyDetailScreen extends ConsumerStatefulWidget {
  const JourneyDetailScreen({super.key, required this.journey});

  final Journey journey;

  @override
  ConsumerState<JourneyDetailScreen> createState() =>
      _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends ConsumerState<JourneyDetailScreen> {
  late PaymentStatus _paymentStatus;

  @override
  void initState() {
    super.initState();
    _paymentStatus = widget.journey.paymentStatus;
  }

  Color get _zoneColor {
    switch (widget.journey.zoneId) {
      case 'ccz':
        return AppColors.cczRed;
      case 'ulez':
        return AppColors.ulezOrange;
      case 'lez':
        return AppColors.lezGreen;
      case 'dartford':
        return const Color(0xFF1565C0);
      case 'silvertown':
        return const Color(0xFF00897B);
      case 'blackwall':
        return const Color(0xFFF57C00);
      default:
        return AppColors.primary;
    }
  }

  Future<void> _setPaymentStatus(PaymentStatus newStatus) async {
    final repo = ref.read(journeyRepositoryProvider);
    await repo.updatePaymentStatus(widget.journey.id, newStatus);
    setState(() => _paymentStatus = newStatus);
    // Refresh history list and monthly total so they both reflect the change
    final selectedVehicle = ref.read(selectedVehicleProvider);
    ref.invalidate(journeyHistoryProvider(selectedVehicle?.registration));
    if (selectedVehicle != null) {
      ref.invalidate(monthlyTotalProvider(selectedVehicle.registration));
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final isPremium = ref.watch(isPremiumProvider);
    final hasRoute = journey.routePoints != null &&
        journey.routePoints!.length > 1;
    final entryPoint = LatLng(journey.entryLat, journey.entryLng);

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('entry'),
        position: entryPoint,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Zone Entry',
          snippet: DateFormat('HH:mm').format(journey.entryTime),
        ),
      ),
      if (journey.exitLat != null && journey.exitLng != null)
        Marker(
          markerId: const MarkerId('exit'),
          position: LatLng(journey.exitLat!, journey.exitLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Zone Exit',
            snippet: journey.exitTime != null
                ? DateFormat('HH:mm').format(journey.exitTime!)
                : '',
          ),
        ),
    };

    final Set<Polyline> polylines = {};
    if (hasRoute && isPremium) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        color: _zoneColor,
        width: 4,
        points: journey.routePoints!
            .map((p) => LatLng(p['lat']!, p['lng']!))
            .toList(),
      ));
    }

    final isPaid = _paymentStatus == PaymentStatus.paid;
    final isExempt = _paymentStatus == PaymentStatus.exempt;

    return Scaffold(
      appBar: AppBar(
        title: Text(journey.zoneName),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map
            SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: entryPoint,
                  zoom: 14.5,
                ),
                markers: markers,
                polylines: polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),

            if (isPremium && !hasRoute)
              Container(
                width: double.infinity,
                color: AppColors.primary.withOpacity(0.07),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Exact route not recorded. Enable "Record exact route" in Settings.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withOpacity(0.8)),
                  textAlign: TextAlign.center,
                ),
              ),

            if (!isPremium)
              Container(
                width: double.infinity,
                color: AppColors.premium.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onTap: () => context.push('/subscription'),
                  child: const Text(
                    'Upgrade to Pro to record your exact route through charge zones.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.premium),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zone badge + payment status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _zoneColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          journey.zoneName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      _PaymentChip(status: _paymentStatus),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Details
                  _DetailRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value: journey.vehicleRegistration,
                  ),
                  _DetailRow(
                    icon: Icons.login,
                    label: 'Entry',
                    value: DateFormat('EEE d MMM yyyy, HH:mm')
                        .format(journey.entryTime),
                  ),
                  if (journey.exitTime != null)
                    _DetailRow(
                      icon: Icons.logout,
                      label: 'Exit',
                      value: DateFormat('EEE d MMM yyyy, HH:mm')
                          .format(journey.exitTime!),
                    ),
                  if (journey.duration != null)
                    _DetailRow(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: _formatDuration(journey.duration!),
                    ),
                  if (!isExempt)
                    _DetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Charge',
                      value: '£${journey.charge.toStringAsFixed(2)}',
                      valueStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isPaid ? AppColors.safe : AppColors.danger,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 3-way payment status selector
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<PaymentStatus>(
                      segments: const [
                        ButtonSegment(
                          value: PaymentStatus.unpaid,
                          label: Text('Unpaid'),
                          icon: Icon(Icons.warning_amber_outlined),
                        ),
                        ButtonSegment(
                          value: PaymentStatus.paid,
                          label: Text('Paid'),
                          icon: Icon(Icons.check_circle_outline),
                        ),
                        ButtonSegment(
                          value: PaymentStatus.exempt,
                          label: Text('Exempt'),
                          icon: Icon(Icons.block_outlined),
                        ),
                      ],
                      selected: {_paymentStatus},
                      onSelectionChanged: (s) => _setPaymentStatus(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PaymentStatus.paid => const Chip(
          label: Text('PAID',
              style: TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: AppColors.safe,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      PaymentStatus.exempt => const Chip(
          label: Text('EXEMPT',
              style: TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      PaymentStatus.unpaid => const Chip(
          label: Text('UNPAID',
              style: TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: AppColors.danger,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
    };
  }
}
