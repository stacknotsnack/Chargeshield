import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/dvla_service.dart';
import '../../../core/services/mot_tax_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/vehicle.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../providers/vehicles_provider.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key, this.vehicle});

  /// When non-null, the screen is in edit mode and pre-fills fields from this vehicle.
  final Vehicle? vehicle;

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regController = TextEditingController();
  final _nicknameController = TextEditingController();

  String _type = 'car';
  String _fuelType = 'petrol';
  String _euroStandard = 'Euro 6';
  bool _saving = false;
  bool _looking = false;   // true while DVLA lookup is in progress
  String? _lookupMake;     // populated after a successful lookup
  DateTime? _motExpiry;    // from DVLA lookup
  DateTime? _taxDue;       // from DVLA lookup

  bool get _isEditMode => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _regController.text = v.registration;
      _nicknameController.text = v.nickname;
      _type = v.type;
      _fuelType = v.fuelType;
      _euroStandard = v.euroStandard;
    }
  }

  static const _vehicleTypes = ['car', 'van', 'motorbike', 'hgv', 'bus', 'coach'];
  static const _fuelTypes = ['petrol', 'diesel', 'electric', 'hybrid', 'phev'];
  static const _euroStandards = [
    'Pre-Euro',
    'Euro 1',
    'Euro 2',
    'Euro 3',
    'Euro 4',
    'Euro 5',
    'Euro 6',
    'Electric',
  ];

  @override
  void dispose() {
    _regController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _lookupVehicle() async {
    final reg = _regController.text.trim();
    if (reg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a registration number first.')),
      );
      return;
    }
    setState(() { _looking = true; _lookupMake = null; });
    try {
      final result = await DvlaService.instance.lookup(reg);
      setState(() {
        _type = result.vehicleType;
        _fuelType = result.fuelType;
        _euroStandard = result.euroStandard;
        _lookupMake = result.make;
        _motExpiry = result.motExpiryDate;
        _taxDue = result.taxDueDate;
        // Pre-fill nickname with make + year if blank
        if (_nicknameController.text.isEmpty) {
          _nicknameController.text =
              '${_capitalize(result.make)} ${result.yearOfManufacture}';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found: ${result.make}${result.colour != null ? ' (${_capitalize(result.colour!)})' : ''} '
              '· ${result.yearOfManufacture} · ${result.euroStandard}',
            ),
            backgroundColor: AppColors.safe,
          ),
        );
      }
    } on DvlaException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach DVLA — check your connection.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(vehiclesProvider.notifier);
      if (_isEditMode) {
        final v = widget.vehicle!;
        v.registration = _regController.text.toUpperCase().trim();
        v.nickname = _nicknameController.text.trim();
        v.type = _type;
        v.fuelType = _fuelType;
        v.euroStandard = _euroStandard;
        await notifier.updateVehicle(v);
      } else {
        await notifier.addVehicle(
          registration: _regController.text,
          nickname: _nicknameController.text,
          type: _type,
          fuelType: _fuelType,
          euroStandard: _euroStandard,
        );
      }
      // Store MOT/tax dates and schedule reminders if we have them
      if (_motExpiry != null || _taxDue != null) {
        final reg = _isEditMode
            ? widget.vehicle!.registration
            : _regController.text.toUpperCase().trim();
        final nickname = _nicknameController.text.trim();
        await MotTaxService.instance.saveDates(
          reg,
          mot: _motExpiry,
          tax: _taxDue,
        );
        final isPremium = ref.read(subscriptionProvider).isPremium;
        if (isPremium) {
          await NotificationService.instance.scheduleMotTaxReminders(
            registration: reg,
            nickname: nickname,
            motExpiry: _motExpiry,
            taxDue: _taxDue,
          );
        }
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Vehicle' : 'Add Vehicle'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Registration plate + DVLA lookup
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Registration Number',
                      hintText: 'e.g. AB12 CDE',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Registration is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton(
                      onPressed: (_looking || _saving) ? null : _lookupVehicle,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: _looking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Look Up'),
                    ),
                  ),
                ),
              ],
            ),

            // Vehicle found banner
            if (_lookupMake != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.safe.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.safe),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.safe, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Vehicle details filled from DVLA for $_lookupMake',
                      style: const TextStyle(
                          color: AppColors.safe, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Nickname
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                hintText: 'e.g. My Blue Ford Focus',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nickname is required' : null,
            ),
            const SizedBox(height: 16),

            // Vehicle type
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              items: _vehicleTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(_capitalize(t))))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),

            // Fuel type
            DropdownButtonFormField<String>(
              value: _fuelType,
              decoration: const InputDecoration(
                labelText: 'Fuel Type',
                prefixIcon: Icon(Icons.local_gas_station_outlined),
              ),
              items: _fuelTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(_capitalize(t))))
                  .toList(),
              onChanged: (v) => setState(() => _fuelType = v!),
            ),
            const SizedBox(height: 16),

            // Euro standard
            DropdownButtonFormField<String>(
              value: _euroStandard,
              decoration: const InputDecoration(
                labelText: 'Euro Emission Standard',
                prefixIcon: Icon(Icons.eco_outlined),
              ),
              items: _euroStandards
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _euroStandard = v!),
            ),

            const SizedBox(height: 8),
            // ULEZ compliance hint
            _UlezComplianceHint(fuelType: _fuelType, euroStandard: _euroStandard),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEditMode ? 'Save Changes' : 'Add Vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _UlezComplianceHint extends StatelessWidget {
  const _UlezComplianceHint(
      {required this.fuelType, required this.euroStandard});

  final String fuelType;
  final String euroStandard;

  bool get _isCompliant {
    if (fuelType == 'electric' || fuelType == 'phev') return true;
    // Petrol and petrol hybrids: ULEZ compliant from Euro 4
    if (fuelType == 'petrol' || fuelType == 'hybrid') {
      return ['Euro 4', 'Euro 5', 'Euro 6'].contains(euroStandard);
    }
    if (fuelType == 'diesel') {
      return euroStandard == 'Euro 6';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isCompliant
            ? AppColors.safe.withOpacity(0.1)
            : AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _isCompliant ? AppColors.safe : AppColors.danger),
      ),
      child: Row(
        children: [
          Icon(
            _isCompliant ? Icons.check_circle : Icons.cancel,
            color: _isCompliant ? AppColors.safe : AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isCompliant
                  ? 'This vehicle is ULEZ compliant — no ULEZ charge.'
                  : 'This vehicle is NOT ULEZ compliant — £12.50/day charge applies.',
              style: TextStyle(
                color: _isCompliant ? AppColors.safe : AppColors.danger,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
