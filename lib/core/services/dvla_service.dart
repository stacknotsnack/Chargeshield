import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result returned from a DVLA VES lookup.
class DvlaVehicleResult {
  const DvlaVehicleResult({
    required this.make,
    required this.fuelType,
    required this.vehicleType,
    required this.euroStandard,
    required this.yearOfManufacture,
    this.colour,
    this.co2Emissions,
    this.motExpiryDate,
    this.taxDueDate,
  });

  final String make;
  final String fuelType;
  final String vehicleType;
  final String euroStandard;
  final int yearOfManufacture;
  final String? colour;
  final int? co2Emissions;
  final DateTime? motExpiryDate; // from DVLA field "motExpiryDate" yyyy-MM-dd
  final DateTime? taxDueDate;    // from DVLA field "taxDueDate"    yyyy-MM-dd
}

class DvlaService {
  DvlaService._();
  static final DvlaService instance = DvlaService._();

  // API key is injected at build time via --dart-define=DVLA_API_KEY=xxx
  // Get a free key at: https://developer-portal.driver-vehicle-licensing.api.gov.uk/
  static const _apiKey = String.fromEnvironment('DVLA_API_KEY', defaultValue: '');

  static const _endpoint =
      'https://driver-vehicle-licensing.api.gov.uk/vehicle-enquiry/v1/vehicles';

  /// Looks up a UK registration plate.
  /// Throws a [DvlaException] with a user-friendly message on failure.
  Future<DvlaVehicleResult> lookup(String registration) async {
    if (_apiKey.isEmpty) {
      throw const DvlaException(
          'DVLA API key not configured. Ask the developer to add it.');
    }

    final clean = registration.replaceAll(' ', '').toUpperCase();

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'x-api-key': _apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'registrationNumber': clean}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      throw const DvlaException('Registration not found. Check the plate and try again.');
    }
    if (response.statusCode == 400) {
      throw const DvlaException('Invalid registration format.');
    }
    if (response.statusCode != 200) {
      throw DvlaException('DVLA lookup failed (${response.statusCode}). Try again.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return DvlaVehicleResult(
      make: (data['make'] as String? ?? 'Unknown').toUpperCase(),
      fuelType: _mapFuelType(data['fuelType'] as String? ?? ''),
      vehicleType: _mapVehicleType(data['typeApproval'] as String? ?? ''),
      euroStandard: _deriveEuroStandard(
        data['fuelType'] as String? ?? '',
        data['yearOfManufacture'] as int? ?? 2000,
      ),
      yearOfManufacture: data['yearOfManufacture'] as int? ?? 0,
      colour: data['colour'] as String?,
      co2Emissions: data['co2Emissions'] as int?,
      motExpiryDate: data['motExpiryDate'] != null
          ? DateTime.tryParse(data['motExpiryDate'] as String)
          : null,
      taxDueDate: data['taxDueDate'] != null
          ? DateTime.tryParse(data['taxDueDate'] as String)
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // Mapping helpers
  // -------------------------------------------------------------------------

  static String _mapFuelType(String dvla) {
    switch (dvla.toUpperCase()) {
      case 'PETROL':
        return 'petrol';
      case 'DIESEL':
        return 'diesel';
      case 'ELECTRIC':
        return 'electric';
      case 'HYBRID ELECTRIC':
      case 'MILD HYBRID ELECTRIC (PETROL)':
      case 'MILD HYBRID ELECTRIC (DIESEL)':
        return 'hybrid';
      case 'PLUG-IN HYBRID ELECTRIC (PHEV)':
      case 'PLUG-IN HYBRID ELECTRIC (DIESEL)':
        return 'phev';
      default:
        return 'petrol'; // safe fallback
    }
  }

  /// Maps DVLA type approval codes to app vehicle types.
  /// M1 = car · M2/M3 = bus/coach · N1 = van · N2/N3 = HGV · L = motorbike
  static String _mapVehicleType(String typeApproval) {
    final t = typeApproval.toUpperCase();
    if (t.startsWith('M1')) return 'car';
    if (t.startsWith('M2') || t.startsWith('M3')) return 'bus';
    if (t.startsWith('N1')) return 'van';
    if (t.startsWith('N2') || t.startsWith('N3')) return 'hgv';
    if (t.startsWith('L')) return 'motorbike';
    return 'car'; // safe fallback
  }

  /// Derives the Euro emission standard from fuel type and year of manufacture.
  /// These are approximate registration-year thresholds (EU directive dates).
  static String _deriveEuroStandard(String fuelType, int year) {
    final fuel = fuelType.toUpperCase();

    if (fuel == 'ELECTRIC') return 'Electric';

    if (fuel == 'PETROL' ||
        fuel == 'HYBRID ELECTRIC' ||
        fuel.contains('PETROL')) {
      if (year >= 2015) return 'Euro 6';
      if (year >= 2011) return 'Euro 5';
      if (year >= 2006) return 'Euro 4';
      if (year >= 2001) return 'Euro 3';
      if (year >= 1997) return 'Euro 2';
      if (year >= 1993) return 'Euro 1';
      return 'Pre-Euro';
    }

    if (fuel == 'DIESEL' || fuel.contains('DIESEL')) {
      if (year >= 2015) return 'Euro 6';
      if (year >= 2011) return 'Euro 5';
      if (year >= 2007) return 'Euro 4';
      if (year >= 2001) return 'Euro 3';
      if (year >= 1997) return 'Euro 2';
      if (year >= 1993) return 'Euro 1';
      return 'Pre-Euro';
    }

    return 'Euro 6'; // PHEV/other default
  }
}

class DvlaException implements Exception {
  const DvlaException(this.message);
  final String message;

  @override
  String toString() => message;
}
