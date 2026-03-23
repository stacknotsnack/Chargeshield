import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/zone_polygons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/journey.dart';
import '../../vehicles/providers/vehicles_provider.dart';
import '../../history/providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedVehicle = ref.watch(selectedVehicleProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final historyAsync =
        ref.watch(journeyHistoryProvider(selectedVehicle?.registration));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey History'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (!isPremium)
            TextButton.icon(
              onPressed: () => context.push('/subscription'),
              icon: const Icon(Icons.workspace_premium,
                  color: AppColors.premium, size: 18),
              label: const Text('Upgrade',
                  style: TextStyle(color: AppColors.premium)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!isPremium)
            Container(
              width: double.infinity,
              color: AppColors.primary.withOpacity(0.08),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Showing last 7 days. Upgrade for full history.',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: historyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading history: $e')),
              data: (journeys) {
                if (journeys.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No journeys recorded yet.',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Start tracking to log zone entries.',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(journeyHistoryProvider(selectedVehicle?.registration)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: journeys.length,
                    itemBuilder: (context, i) => _JourneyCard(
                      journey: journeys[i],
                      onTap: () => context.push(
                        '/history/${journeys[i].id}',
                        extra: journeys[i],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends ConsumerStatefulWidget {
  const _JourneyCard({required this.journey, required this.onTap});

  final Journey journey;
  final VoidCallback onTap;

  @override
  ConsumerState<_JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends ConsumerState<_JourneyCard> {
  late PaymentStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.journey.paymentStatus;
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

  String? get _payUrl {
    try {
      return AllZones.allForDisplay
          .firstWhere((z) => z.id == widget.journey.zoneId)
          .payUrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPayNow() async {
    final url = _payUrl;
    if (url == null || url.isEmpty) return;

    // Open payment URL
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    // Ask to mark as paid
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: const Text(
            'Have you completed payment for this charge?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, mark paid')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(journeyRepositoryProvider)
          .updatePaymentStatus(widget.journey.id, PaymentStatus.paid);
      setState(() => _status = PaymentStatus.paid);
      // Refresh monthly total on home screen
      ref.invalidate(monthlyTotalProvider(widget.journey.vehicleRegistration));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = _status == PaymentStatus.paid;
    final isExempt = _status == PaymentStatus.exempt;
    final isUnpaid = _status == PaymentStatus.unpaid;
    final hasPayUrl = (_payUrl ?? '').isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _zoneColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.journey.zoneName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  _PaymentBadge(status: _status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.login, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEE d MMM, HH:mm')
                        .format(widget.journey.entryTime),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              if (widget.journey.exitTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.logout, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(widget.journey.exitTime!),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(widget.journey.duration!),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    widget.journey.vehicleRegistration,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, letterSpacing: 1.0),
                  ),
                  const Spacer(),
                  if (!isExempt)
                    Text(
                      '£${widget.journey.charge.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPaid ? AppColors.safe : AppColors.danger,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
              // Pay now button / Paid badge
              if (!isExempt && widget.journey.charge > 0) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                if (isPaid)
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: AppColors.safe, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Paid',
                        style: TextStyle(
                            color: AppColors.safe,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  )
                else if (isUnpaid && hasPayUrl)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _onPayNow,
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('Pay now →'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B), // teal
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PaymentStatus.paid => const Chip(
          label: Text('PAID', style: TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: AppColors.safe,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      PaymentStatus.exempt => const Chip(
          label: Text('EXEMPT', style: TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      PaymentStatus.unpaid => const Chip(
          label: Text('UNPAID', style: TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: AppColors.danger,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
    };
  }
}
