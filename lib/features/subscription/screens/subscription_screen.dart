import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../history/providers/history_provider.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(subscriptionProvider.notifier);
    final success =
        await notifier.activateLicenceKey(_keyController.text);
    if (success && mounted) {
      // Keep isPremiumProvider in sync — history/vehicles providers watch it.
      ref.read(isPremiumProvider.notifier).state = true;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.workspace_premium,
              color: AppColors.premium, size: 48),
          title: const Text('Pro Activated!'),
          content: const Text(
            'Welcome to ChargeShield Pro.\n\nAll Pro features are now unlocked.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);

    if (state.isPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ChargeShield Pro'),
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium,
                    size: 80, color: AppColors.premium),
                const SizedBox(height: 20),
                const Text(
                  'You\'re on ChargeShield Pro!',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('All features unlocked.',
                    style: TextStyle(color: Colors.grey)),
                if (state.licenceKey != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Key: ${state.licenceKey}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Pro'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(Icons.workspace_premium,
                size: 72, color: AppColors.premium),
            const SizedBox(height: 16),
            const Text(
              'ChargeShield Pro',
              style:
                  TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Never miss a charge zone payment again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 32),

            // Features comparison
            const _ComparisonTable(),
            const SizedBox(height: 32),

            // Pricing cards
            const _PricingCard(
              title: 'Monthly',
              price: '£2.99',
              period: '/month',
            ),
            const SizedBox(height: 12),
            const _PricingCard(
              title: 'Annual',
              price: '£19.99',
              period: '/year',
              badge: 'SAVE 44%',
              highlighted: true,
            ),
            const SizedBox(height: 16),

            // Buy button
            FilledButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://chargeshield.co.uk'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Buy on chargeshield.co.uk'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.premium,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 20),

            // Licence key entry
            Text(
              'Already purchased? Enter your licence key',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Your key is in your purchase confirmation email.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _keyController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Licence Key',
                      hintText: 'CS-XXXX-XXXX-XXXX',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your licence key'
                        : null,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.error!,
                      style:
                          const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        state.isActivating ? null : _activate,
                    child: state.isActivating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Activate Licence Key'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  @override
  Widget build(BuildContext context) {
    const features = [
      ('Vehicles', '1', '10'),
      ('Alert zones', 'ULEZ & Dartford', 'All 6 zones'),
      ('Zone entry alerts', '15/month', 'Unlimited'),
      ('Journey history', '7 days', '12 months'),
      ('Monthly cost report', false, true),
      ('Priority notifications', false, true),
    ];

    return Card(
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Expanded(
                    child: Text('Feature',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 70,
                    child: Text('Free',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 70,
                    child: Text('Pro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.premium,
                            fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          ...features.map((f) => _FeatureRow(
                label: f.$1,
                free: f.$2,
                pro: f.$3,
              )),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.label,
    required this.free,
    required this.pro,
  });

  final String label;
  final dynamic free;
  final dynamic pro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(fontSize: 13))),
          SizedBox(width: 70, child: _cell(free)),
          SizedBox(width: 70, child: _cell(pro)),
        ],
      ),
    );
  }

  Widget _cell(dynamic value) {
    if (value is bool) {
      return Icon(
        value
            ? Icons.check_circle
            : Icons.remove_circle_outline,
        color: value ? AppColors.safe : Colors.grey,
        size: 18,
      );
    }
    return Text(
      value as String,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: highlighted
              ? AppColors.premium
              : Colors.grey.shade300,
          width: highlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: highlighted
            ? AppColors.premium.withValues(alpha: 0.05)
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.premium,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                          text: price,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      TextSpan(
                          text: period,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
