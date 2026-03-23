import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Polygon boundary data for London charge zones.
/// Coordinates are approximate but accurate enough for entry detection.
class ZonePolygons {
  ZonePolygons._();

  // ---------------------------------------------------------------------------
  // Congestion Charge Zone (CCZ)
  // Operates: Mon–Fri 07:00–18:00, Sat 12:00–18:00
  // Charge: £18/day for most vehicles (increased from £15 on 2 Jan 2026)
  // ---------------------------------------------------------------------------
  static const List<LatLng> ccz = [
    LatLng(51.5224, -0.1868), // Edgware Rd / Marylebone Flyover
    LatLng(51.5267, -0.1580), // Great Portland St
    LatLng(51.5285, -0.1375), // Warren Street
    LatLng(51.5298, -0.1225), // Euston / Kings Cross
    LatLng(51.5290, -0.1070), // Pentonville Rd
    LatLng(51.5270, -0.0890), // Angel / City Road
    LatLng(51.5225, -0.0760), // Old Street
    LatLng(51.5190, -0.0680), // Shoreditch
    LatLng(51.5150, -0.0630), // Liverpool Street
    LatLng(51.5110, -0.0640), // Aldgate
    LatLng(51.5065, -0.0720), // Tower Hill
    LatLng(51.5020, -0.0820), // London Bridge south approach
    LatLng(51.4985, -0.0990), // Borough
    LatLng(51.4955, -0.1170), // Elephant & Castle
    LatLng(51.4940, -0.1350), // Vauxhall
    LatLng(51.4945, -0.1510), // Nine Elms
    LatLng(51.4965, -0.1690), // Battersea / Chelsea Bridge
    LatLng(51.4985, -0.1830), // Pimlico
    LatLng(51.4998, -0.1920), // Sloane Square
    LatLng(51.5025, -0.1990), // Chelsea / Kings Road
    LatLng(51.5070, -0.2010), // Hyde Park Corner west
    LatLng(51.5095, -0.1990), // Knightsbridge
    LatLng(51.5140, -0.1940), // Hyde Park Corner north
    LatLng(51.5165, -0.1890), // Marble Arch / Park Lane
    LatLng(51.5200, -0.1885), // Park Lane north
    LatLng(51.5224, -0.1868), // back to start
  ];

  // ---------------------------------------------------------------------------
  // Ultra Low Emission Zone (ULEZ) — expanded Aug 2023
  // Covers all 33 London boroughs (whole of Greater London)
  // 24/7, 365 days/year
  // Boundary derived from Greater London Authority administrative boundary
  // (GeoJSON source: London Datastore / GLA boundary data, ~100-point simplification)
  // ---------------------------------------------------------------------------
  static const List<LatLng> ulez = [
    LatLng(51.4558, -0.4571),
    LatLng(51.4606, -0.4748),
    LatLng(51.4618, -0.4888),
    LatLng(51.4672, -0.5049),
    LatLng(51.4748, -0.5034),
    LatLng(51.4880, -0.4976),
    LatLng(51.4914, -0.4937),
    LatLng(51.4969, -0.4875),
    LatLng(51.5013, -0.4847),
    LatLng(51.5069, -0.4818),
    LatLng(51.5146, -0.4893),
    LatLng(51.5286, -0.4874),
    LatLng(51.5381, -0.4939),
    LatLng(51.5465, -0.4879),
    LatLng(51.5584, -0.4753),
    LatLng(51.5662, -0.4831),
    LatLng(51.5776, -0.4879),
    LatLng(51.5913, -0.4970),
    LatLng(51.6012, -0.4952),
    LatLng(51.6136, -0.4964),
    LatLng(51.6257, -0.4962),
    LatLng(51.6270, -0.4874),
    LatLng(51.6157, -0.4464),
    LatLng(51.6164, -0.4193),
    LatLng(51.6190, -0.3697),
    LatLng(51.6332, -0.3315),
    LatLng(51.6360, -0.2901),
    LatLng(51.6426, -0.2595),
    LatLng(51.6583, -0.2351),
    LatLng(51.6659, -0.1945),
    LatLng(51.6858, -0.1434),
    LatLng(51.6895, -0.0915),
    LatLng(51.6824, -0.0562),
    LatLng(51.6812, -0.0229),
    LatLng(51.6673, -0.0096),
    LatLng(51.6503, -0.0100),
    LatLng(51.6408,  0.0127),
    LatLng(51.6224,  0.0333),
    LatLng(51.6163,  0.0534),
    LatLng(51.6065,  0.0808),
    LatLng(51.6177,  0.1265),
    LatLng(51.6251,  0.1826),
    LatLng(51.6294,  0.2226),
    LatLng(51.6078,  0.2661),
    LatLng(51.6028,  0.2578),
    LatLng(51.5910,  0.2718),
    LatLng(51.5734,  0.2872),
    LatLng(51.5646,  0.3021),
    LatLng(51.5524,  0.3270),
    LatLng(51.5388,  0.3109),
    LatLng(51.5203,  0.2656),
    LatLng(51.5277,  0.2527),
    LatLng(51.5128,  0.2419),
    LatLng(51.5063,  0.2316),
    LatLng(51.4964,  0.2196),
    LatLng(51.4792,  0.2183),
    LatLng(51.4604,  0.2085),
    LatLng(51.4519,  0.2009),
    LatLng(51.4514,  0.1956),
    LatLng(51.4420,  0.1739),
    LatLng(51.4299,  0.1596),
    LatLng(51.4100,  0.1550),
    LatLng(51.4051,  0.1550),
    LatLng(51.3903,  0.1514),
    LatLng(51.3811,  0.1520),
    LatLng(51.3677,  0.1530),
    LatLng(51.3598,  0.1470),
    LatLng(51.3504,  0.1443),
    LatLng(51.3455,  0.1391),
    LatLng(51.3441,  0.1387),
    LatLng(51.3408,  0.1183),
    LatLng(51.3252,  0.1028),
    LatLng(51.3075,  0.0857),
    LatLng(51.2913,  0.0829),
    LatLng(51.2897,  0.0672),
    LatLng(51.2916,  0.0578),
    LatLng(51.2934,  0.0485),
    LatLng(51.3027,  0.0417),
    LatLng(51.2918,  0.0162),
    LatLng(51.3152,  0.0091),
    LatLng(51.3333, -0.0166),
    LatLng(51.3289, -0.0479),
    LatLng(51.3176, -0.0774),
    LatLng(51.3083, -0.0851),
    LatLng(51.2894, -0.1148),
    LatLng(51.2990, -0.1391),
    LatLng(51.3202, -0.1569),
    LatLng(51.3400, -0.1991),
    LatLng(51.3399, -0.2207),
    LatLng(51.3655, -0.2316),
    LatLng(51.3790, -0.2593),
    LatLng(51.3652, -0.2811),
    LatLng(51.3489, -0.2960),
    LatLng(51.3261, -0.3227),
    LatLng(51.3536, -0.3226),
    LatLng(51.3863, -0.3099),
    LatLng(51.4023, -0.3387),
    LatLng(51.4075, -0.3758),
    LatLng(51.4230, -0.3987),
    LatLng(51.4284, -0.4291),
    LatLng(51.4534, -0.4575),
    LatLng(51.4558, -0.4571), // back to start
  ];

  // ---------------------------------------------------------------------------
  // Silvertown Tunnel (tight corridor)
  // North portal: 51.5075, 0.0162 (Silvertown/Newham)
  // South portal: 51.4985, 0.0075 (Greenwich Peninsula)
  // Charged via Dart Charge — pay by midnight 3 days after crossing.
  // Charge: £4.00 peak · £1.50 off-peak with AutoPay. Motorcycles free.
  //
  // Tight N-S corridor: lat 51.496–51.510, lng 0.010–0.022
  // ---------------------------------------------------------------------------
  static const List<LatLng> silvertown = [
    LatLng(51.5065, 0.0085), // NW — Silvertown Tunnel north approach, east of Blackwall
    LatLng(51.5065, 0.0185), // NE
    LatLng(51.4990, 0.0185), // SE
    LatLng(51.4990, 0.0085), // SW
    LatLng(51.5065, 0.0085), // back to start
  ];

  // ---------------------------------------------------------------------------
  // Blackwall Tunnel (tight corridor)
  // North portal: 51.5075, 0.0025 (Poplar/Tower Hamlets)
  // South portal: 51.4905, 0.0025 (Greenwich)
  // Same Dart Charge scheme as Silvertown Tunnel.
  //
  // Tight N-S corridor: lat 51.488–51.510, lng -0.003–0.008
  // ---------------------------------------------------------------------------
  static const List<LatLng> blackwall = [
    LatLng(51.5065, -0.0055), // NW — A102 north approach, south of East India Dock Rd
    LatLng(51.5065,  0.0030), // NE
    LatLng(51.4990,  0.0030), // SE
    LatLng(51.4990, -0.0055), // SW
    LatLng(51.5065, -0.0055), // back to start
  ];

  // ---------------------------------------------------------------------------
  // Dartford Crossing (Dart Charge)
  // M25 Thames crossing between Thurrock (Essex) and Dartford (Kent)
  // QE2 Bridge (southbound) + East/West Tunnels (northbound)
  // Charge: £3.50 cars · £4.20 vans · £8.40 HGV — FREE 22:00–06:00
  // Pay by midnight the day after crossing at dartcharge.co.uk
  //
  // Tight A282 corridor: lat 51.450–51.478, lng 0.255–0.262
  // ~400m either side of A282 centreline (0.2587). Avoids A1089 to the west.
  // ---------------------------------------------------------------------------
  static const List<LatLng> dartford = [
    LatLng(51.469, 0.256), // NW — river crossing north bank
    LatLng(51.469, 0.261), // NE
    LatLng(51.460, 0.261), // SE — river crossing south bank
    LatLng(51.460, 0.256), // SW
    LatLng(51.469, 0.256), // back to start
  ];

  // ---------------------------------------------------------------------------
  // Low Emission Zone (LEZ)
  // Affects: heavy vehicles (HGVs, buses, coaches, larger vans)
  // Covers: virtually all of Greater London (slightly larger than ULEZ boundary)
  // 24/7, 365 days/year
  // ---------------------------------------------------------------------------
  static const List<LatLng> lez = [
    // Same shape as ULEZ but with a ~1km outward buffer and extended east
    // to cover the A282/Purfleet approach roads used by HGVs
    LatLng(51.4540, -0.4630),
    LatLng(51.4580, -0.4820),
    LatLng(51.4600, -0.5000),
    LatLng(51.4650, -0.5160),
    LatLng(51.4740, -0.5150),
    LatLng(51.4880, -0.5090),
    LatLng(51.4930, -0.5050),
    LatLng(51.4990, -0.4990),
    LatLng(51.5040, -0.4960),
    LatLng(51.5100, -0.4930),
    LatLng(51.5170, -0.5010),
    LatLng(51.5300, -0.4990),
    LatLng(51.5400, -0.5060),
    LatLng(51.5490, -0.5000),
    LatLng(51.5610, -0.4870),
    LatLng(51.5690, -0.4960),
    LatLng(51.5810, -0.5010),
    LatLng(51.5950, -0.5100),
    LatLng(51.6060, -0.5080),
    LatLng(51.6190, -0.5090),
    LatLng(51.6310, -0.5090),
    LatLng(51.6330, -0.4990),
    LatLng(51.6210, -0.4570),
    LatLng(51.6220, -0.4290),
    LatLng(51.6250, -0.3780),
    LatLng(51.6400, -0.3390),
    LatLng(51.6430, -0.2960),
    LatLng(51.6500, -0.2650),
    LatLng(51.6660, -0.2400),
    LatLng(51.6740, -0.1990),
    LatLng(51.6950, -0.1470),
    LatLng(51.6990, -0.0930),
    LatLng(51.6910, -0.0570),
    LatLng(51.6900, -0.0230),
    LatLng(51.6760, -0.0090),
    LatLng(51.6590, -0.0100),
    LatLng(51.6490,  0.0140),
    LatLng(51.6300,  0.0350),
    LatLng(51.6240,  0.0560),
    LatLng(51.6140,  0.0840),
    LatLng(51.6260,  0.1310),
    LatLng(51.6340,  0.1880),
    LatLng(51.6390,  0.2290),
    LatLng(51.6210,  0.2780),
    LatLng(51.6160,  0.2690),
    LatLng(51.6030,  0.2850),
    LatLng(51.5860,  0.3020),
    LatLng(51.5760,  0.3190),
    // Extended east past GLA boundary for Purfleet/A282 HGV routes
    LatLng(51.5650,  0.3450),
    LatLng(51.5540,  0.3620),
    LatLng(51.5480,  0.3460),
    LatLng(51.5410,  0.3310),
    LatLng(51.5280,  0.2810),
    LatLng(51.5360,  0.2680),
    LatLng(51.5200,  0.2560),
    LatLng(51.5130,  0.2450),
    LatLng(51.5030,  0.2320),
    LatLng(51.4860,  0.2300),
    LatLng(51.4670,  0.2200),
    LatLng(51.4580,  0.2120),
    LatLng(51.4580,  0.2060),
    LatLng(51.4490,  0.1840),
    LatLng(51.4370,  0.1700),
    LatLng(51.4160,  0.1650),
    LatLng(51.4110,  0.1650),
    LatLng(51.3960,  0.1620),
    LatLng(51.3870,  0.1630),
    LatLng(51.3730,  0.1640),
    LatLng(51.3650,  0.1580),
    LatLng(51.3560,  0.1560),
    LatLng(51.3510,  0.1510),
    LatLng(51.3490,  0.1510),
    LatLng(51.3460,  0.1300),
    LatLng(51.3300,  0.1140),
    LatLng(51.3120,  0.0960),
    LatLng(51.2950,  0.0930),
    LatLng(51.2930,  0.0760),
    LatLng(51.2950,  0.0660),
    LatLng(51.2970,  0.0570),
    LatLng(51.3060,  0.0500),
    LatLng(51.2960,  0.0240),
    LatLng(51.3200,  0.0170),
    LatLng(51.3390, -0.0100),
    LatLng(51.3340, -0.0430),
    LatLng(51.3220, -0.0720),
    LatLng(51.3120, -0.0800),
    LatLng(51.2930, -0.1090),
    LatLng(51.3030, -0.1340),
    LatLng(51.3250, -0.1510),
    LatLng(51.3460, -0.1940),
    LatLng(51.3460, -0.2150),
    LatLng(51.3720, -0.2260),
    LatLng(51.3850, -0.2540),
    LatLng(51.3710, -0.2760),
    LatLng(51.3550, -0.2910),
    LatLng(51.3320, -0.3170),
    LatLng(51.3600, -0.3170),
    LatLng(51.3940, -0.3040),
    LatLng(51.4100, -0.3430),
    LatLng(51.4150, -0.3810),
    LatLng(51.4310, -0.4050),
    LatLng(51.4370, -0.4360),
    LatLng(51.4540, -0.4630), // back to start
  ];
}

/// Metadata about each charge zone.
class ZoneInfo {
  const ZoneInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.dailyCharge,
    required this.vehicleCharges,
    required this.payUrl,
    this.polygon = const [],
    required this.color,
    this.operatingHours,
    this.centre,
    this.radiusMetres,
    this.proOnly = false,
    this.comingSoon = false,
    this.isCrossing = false,
  });

  final String id;
  final String name;
  final String shortName;
  final String description;

  final double dailyCharge;
  final Map<String, double> vehicleCharges;
  final String payUrl;

  /// Polygon boundary for map display and ray-cast detection.
  /// Empty for circle-based zones (use [centre] + [radiusMetres] instead).
  final List<LatLng> polygon;
  final int color; // ARGB
  final String? operatingHours;

  /// Circle geofence — when both are set, detection uses Haversine distance
  /// instead of ray-casting. Polygon is still used for map display if non-empty.
  final LatLng? centre;
  final double? radiusMetres;

  /// True for UK-wide zones that require a Pro subscription for notifications.
  final bool proOnly;

  /// True for zones shown on the map but not yet active (Sheffield CAZ etc.).
  /// No detection or notifications fired.
  final bool comingSoon;

  /// True when the charge is per-crossing rather than per-day.
  final bool isCrossing;

  double chargeFor(String vehicleType) =>
      vehicleCharges[vehicleType] ?? dailyCharge;
}

class LondonZones {
  LondonZones._();

  static final List<ZoneInfo> all = [ccz, ulez, lez, dartford, silvertown, blackwall];

  static final ZoneInfo ccz = ZoneInfo(
    id: 'ccz',
    name: 'Congestion Charge Zone',
    shortName: 'CCZ',
    description: 'Central London congestion charge area. '
        'Cars/vans £18/day (from 2 Jan 2026) · Motorcycles free · EVs/PHEVs exempt.',
    dailyCharge: 18.0,
    vehicleCharges: {
      'car': 18.0,
      'van': 18.0,
      'motorbike': 0.0,  // motorcycles & mopeds are exempt from CCZ
      'hgv': 18.0,
      'bus': 18.0,
      'coach': 18.0,
    },
    payUrl: 'https://tfl.gov.uk/modes/driving/congestion-charge/paying-the-congestion-charge',
    polygon: ZonePolygons.ccz,
    color: 0xAAE53935,
    operatingHours: 'Mon–Fri 07:00–18:00, Sat 12:00–18:00',
  );

  static final ZoneInfo ulez = ZoneInfo(
    id: 'ulez',
    name: 'Ultra Low Emission Zone',
    shortName: 'ULEZ',
    description: 'Covers all of Greater London. Non-compliant vehicles: '
        'cars/vans/motorbikes £12.50/day · HGVs/buses £100/day.',
    dailyCharge: 12.50,
    vehicleCharges: {
      'car': 12.50,
      'van': 12.50,
      'motorbike': 12.50,
      'hgv': 100.0,   // heavier vehicles pay the higher ULEZ/LEZ rate
      'bus': 100.0,
      'coach': 100.0,
    },
    payUrl: 'https://tfl.gov.uk/modes/driving/ultra-low-emission-zone/ulez-payments',
    polygon: ZonePolygons.ulez,
    color: 0xAAFB8C00,
    operatingHours: '24 hours, every day',
  );

  static final ZoneInfo lez = ZoneInfo(
    id: 'lez',
    name: 'Low Emission Zone',
    shortName: 'LEZ',
    description: 'Covers Greater London. Applies to heavier vehicles only. '
        'Non-compliant HGVs/buses/coaches: £100/day. Cars & motorcycles not affected.',
    dailyCharge: 100.0,
    vehicleCharges: {
      'car': 0.0,       // LEZ does not apply to cars
      'van': 100.0,     // applies to heavier vans (3.5t+)
      'motorbike': 0.0, // not affected
      'hgv': 100.0,
      'bus': 100.0,
      'coach': 100.0,
    },
    payUrl: 'https://tfl.gov.uk/modes/driving/low-emission-zone/make-a-payment',
    polygon: ZonePolygons.lez,
    color: 0xAA43A047,
    operatingHours: '24 hours, every day',
  );

  static final ZoneInfo dartford = ZoneInfo(
    id: 'dartford',
    name: 'Dartford Crossing',
    shortName: 'DART',
    description: 'M25 Thames crossing (QE2 Bridge & tunnels). '
        'Cars £3.50 (£2.80 with account) · '
        'Vans/2-axle goods £4.20 (£3.60 with account) · '
        'HGVs/buses £8.40 (£7.20 with account) · '
        'Motorcycles free. Free 22:00–06:00.',
    dailyCharge: 3.50,
    vehicleCharges: {
      'car': 3.50,
      'van': 4.20,
      'motorbike': 0.0,
      'hgv': 8.40,
      'bus': 8.40,
      'coach': 8.40,
    },
    payUrl: 'https://pay-dartford-crossing-charge.service.gov.uk/',
    polygon: ZonePolygons.dartford,
    color: 0xAA7B1FA2,
    operatingHours: 'Charged 06:00–22:00 daily. Free overnight.',
    isCrossing: true,
  );

  static final ZoneInfo silvertown = ZoneInfo(
    id: 'silvertown',
    name: 'Silvertown Tunnel',
    shortName: 'SILV',
    description: 'Silvertown Tunnel linking Silvertown (Newham) to Greenwich Peninsula. '
        'Peak £4.00 (06:00–10:00 & 16:00–19:00) · Off-peak £1.50 with AutoPay. '
        'Cars £4.00 · Vans £5.00 · HGVs/buses £8.00 · Motorcycles free. '
        'Pay via Dart Charge by midnight 3 days after crossing. '
        'Penalty: £180 (reduced to £90 if paid within 14 days). Free Christmas Day.',
    dailyCharge: 4.00,
    vehicleCharges: {
      'car': 4.00,
      'van': 5.00,
      'motorbike': 0.0,
      'hgv': 8.00,
      'bus': 8.00,
      'coach': 8.00,
    },
    payUrl: 'https://tfl.gov.uk/modes/driving/silvertown-blackwall-tunnels-charge/paying-blackwall-and-silvertown-tunnel-charges',
    polygon: ZonePolygons.silvertown,
    color: 0xAA00897B, // teal
    operatingHours: 'Charged 06:00–22:00 daily. Free Christmas Day.',
    isCrossing: true,
  );

  static final ZoneInfo blackwall = ZoneInfo(
    id: 'blackwall',
    name: 'Blackwall Tunnel',
    shortName: 'BLKW',
    description: 'Blackwall Tunnel linking Poplar (Tower Hamlets) to Greenwich. '
        'Peak £4.00 (06:00–10:00 & 16:00–19:00) · Off-peak £1.50 with AutoPay. '
        'Cars £4.00 · Vans £5.00 · HGVs/buses £8.00 · Motorcycles free. '
        'Pay via Dart Charge by midnight 3 days after crossing. '
        'Penalty: £180 (reduced to £90 if paid within 14 days). Free Christmas Day.',
    dailyCharge: 4.00,
    vehicleCharges: {
      'car': 4.00,
      'van': 5.00,
      'motorbike': 0.0,
      'hgv': 8.00,
      'bus': 8.00,
      'coach': 8.00,
    },
    payUrl: 'https://tfl.gov.uk/modes/driving/silvertown-blackwall-tunnels-charge/paying-blackwall-and-silvertown-tunnel-charges',
    polygon: ZonePolygons.blackwall,
    color: 0xAA00695C, // darker teal to distinguish from Silvertown
    operatingHours: 'Charged 06:00–22:00 daily. Free Christmas Day.',
    isCrossing: true,
  );
}

// ---------------------------------------------------------------------------
// UK-wide Clean Air Zones and Toll Roads (Pro only)
// ---------------------------------------------------------------------------
class UkZones {
  UkZones._();

  static final ZoneInfo birmingham = ZoneInfo(
    id: 'birmingham',
    name: 'Birmingham Clean Air Zone',
    shortName: 'BHX',
    description: 'Inside A4540 Middleway ring road. Non-compliant cars: £8/day. 24/7. '
        'Penalty: £120 (£60 within 14 days).',
    dailyCharge: 8.0,
    vehicleCharges: {
      'car': 8.0,
      'van': 8.0,
      'motorbike': 0.0,
      'hgv': 50.0,
      'bus': 50.0,
      'coach': 50.0,
    },
    payUrl: 'https://multiple-vehiclecheck-pay.drive-clean-air-zone.service.gov.uk/',
    polygon: const [
      LatLng(52.4927, -1.9206),
      LatLng(52.4927, -1.8773),
      LatLng(52.4698, -1.8773),
      LatLng(52.4698, -1.9206),
    ],
    color: 0xAA2563EB,
    operatingHours: '24 hours, every day',
    centre: const LatLng(52.4813, -1.8990), // centre for map pin only
    proOnly: true,
  );

  static final ZoneInfo bath = ZoneInfo(
    id: 'bath',
    name: 'Bath Clean Air Zone',
    shortName: 'BATH',
    description: 'Bath city centre. Non-compliant cars: £9/day. 24/7.',
    dailyCharge: 9.0,
    vehicleCharges: {
      'car': 9.0,
      'van': 9.0,
      'motorbike': 0.0,
      'hgv': 100.0,
      'bus': 100.0,
      'coach': 100.0,
    },
    payUrl: 'https://multiple-vehiclecheck-pay.drive-clean-air-zone.service.gov.uk/',
    color: 0xAA2563EB,
    operatingHours: '24 hours, every day',
    centre: const LatLng(51.3811, -2.3590),
    radiusMetres: 550,
    proOnly: true,
  );

  static final ZoneInfo portsmouth = ZoneInfo(
    id: 'portsmouth',
    name: 'Portsmouth Clean Air Zone',
    shortName: 'POM',
    description: 'Portsmouth city centre. Non-compliant cars: £10/day. 24/7.',
    dailyCharge: 10.0,
    vehicleCharges: {
      'car': 10.0,
      'van': 10.0,
      'motorbike': 0.0,
      'hgv': 100.0,
      'bus': 100.0,
      'coach': 100.0,
    },
    payUrl: 'https://multiple-vehiclecheck-pay.drive-clean-air-zone.service.gov.uk/',
    color: 0xAA2563EB,
    operatingHours: '24 hours, every day',
    centre: const LatLng(50.7989, -1.0926),
    radiusMetres: 450,
    proOnly: true,
  );

  static final ZoneInfo bradford = ZoneInfo(
    id: 'bradford',
    name: 'Bradford Clean Air Zone',
    shortName: 'BFD',
    description: 'Bradford city centre. Non-compliant cars: £9/day. 24/7.',
    dailyCharge: 9.0,
    vehicleCharges: {
      'car': 9.0,
      'van': 9.0,
      'motorbike': 0.0,
      'hgv': 100.0,
      'bus': 100.0,
      'coach': 100.0,
    },
    payUrl: 'https://multiple-vehiclecheck-pay.drive-clean-air-zone.service.gov.uk/',
    color: 0xAA2563EB,
    operatingHours: '24 hours, every day',
    centre: const LatLng(53.7950, -1.7594),
    radiusMetres: 650,
    proOnly: true,
  );

  static final ZoneInfo m6TollNorth = ZoneInfo(
    id: 'm6_toll_north',
    name: 'M6 Toll (North)',
    shortName: 'M6N',
    description: 'M6 Toll motorway northern entry. Cars £7.10.',
    dailyCharge: 7.10,
    vehicleCharges: {
      'car': 7.10,
      'van': 11.10,
      'motorbike': 5.60,
      'hgv': 12.60,
      'bus': 12.60,
      'coach': 12.60,
    },
    payUrl: 'https://www.m6toll.co.uk/paying-your-toll/',
    color: 0xAAF59E0B,
    operatingHours: '24 hours, every day',
    centre: const LatLng(52.6847, -2.0237),
    radiusMetres: 350,
    proOnly: true,
    isCrossing: true,
  );

  static final ZoneInfo m6TollSouth = ZoneInfo(
    id: 'm6_toll_south',
    name: 'M6 Toll (South)',
    shortName: 'M6S',
    description: 'M6 Toll motorway southern entry. Cars £7.10.',
    dailyCharge: 7.10,
    vehicleCharges: {
      'car': 7.10,
      'van': 11.10,
      'motorbike': 5.60,
      'hgv': 12.60,
      'bus': 12.60,
      'coach': 12.60,
    },
    payUrl: 'https://www.m6toll.co.uk/paying-your-toll/',
    color: 0xAAF59E0B,
    operatingHours: '24 hours, every day',
    centre: const LatLng(52.4869, -1.7718),
    radiusMetres: 350,
    proOnly: true,
    isCrossing: true,
  );

  /// Sheffield — display only. No detection or notifications.
  static final ZoneInfo sheffield = ZoneInfo(
    id: 'sheffield',
    name: 'Sheffield Clean Air Zone',
    shortName: 'SHF',
    description: 'Sheffield city centre. Coming soon — charges not yet active.',
    dailyCharge: 0.0,
    vehicleCharges: {},
    payUrl: '',
    color: 0xAA9CA3AF, // grey
    operatingHours: 'Not yet active',
    centre: const LatLng(53.3811, -1.4701),
    radiusMetres: 800,
    proOnly: true,
    comingSoon: true,
  );

  /// Active UK zones (detected + notify for Pro users).
  static final List<ZoneInfo> active = [
    birmingham,
    bath,
    portsmouth,
    bradford,
    m6TollNorth,
    m6TollSouth,
  ];

  /// All UK zones including coming-soon ones (map display).
  static final List<ZoneInfo> all = [...active, sheffield];
}

/// Combined zone registry used by detection, map, and history.
class AllZones {
  AllZones._();

  /// Zones actively detected and triggering entries/exits/notifications.
  static final List<ZoneInfo> detectableZones = [
    ...LondonZones.all,
    ...UkZones.active,
  ];

  /// All zones for map display (includes coming-soon Sheffield).
  static final List<ZoneInfo> allForDisplay = [
    ...LondonZones.all,
    ...UkZones.all,
  ];
}
