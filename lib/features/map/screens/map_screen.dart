import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/zone_polygons.dart';
import '../../../core/theme/app_colors.dart';
import '../../history/providers/history_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const LatLng _londonCenter = LatLng(51.5074, 0.05);
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  StreamSubscription? _locationSub;
  double _zoom = 10.0;

  final Set<Polygon> _polygons = {};
  final Set<Circle> _circles = {};

  // Region markers shown at low zoom (< 9)
  static final List<_RegionMarker> _regions = [
    _RegionMarker('London', const LatLng(51.5074, -0.1278), 6),
    _RegionMarker('Birmingham', const LatLng(52.4814, -1.8998), 1),
    _RegionMarker('Bath', const LatLng(51.3811, -2.3590), 1),
    _RegionMarker('Portsmouth', const LatLng(50.7989, -1.0926), 1),
    _RegionMarker('Bradford', const LatLng(53.7950, -1.7594), 1),
    _RegionMarker('Sheffield', const LatLng(53.3811, -1.4701), 1),
    _RegionMarker('M6 Toll', const LatLng(52.5700, -1.9357), 2),
  ];

  @override
  void initState() {
    super.initState();
    _buildPolygons();
    _buildCircles();
    _listenToLocation();
  }

  void _buildPolygons() {
    for (final zone in AllZones.allForDisplay) {
      if (zone.polygon.isEmpty) continue; // circle-based zone
      _polygons.add(Polygon(
        polygonId: PolygonId(zone.id),
        points: zone.polygon,
        fillColor: Color(zone.color).withOpacity(zone.comingSoon ? 0.05 : 0.2),
        strokeColor: zone.comingSoon
            ? Colors.grey.withOpacity(0.5)
            : Color(zone.color),
        strokeWidth: zone.comingSoon ? 1 : 2,
        onTap: () => _showZoneInfo(zone),
      ));
    }
  }

  void _buildCircles() {
    for (final zone in AllZones.allForDisplay) {
      if (zone.centre == null || zone.radiusMetres == null) continue;
      _circles.add(Circle(
        circleId: CircleId(zone.id),
        center: zone.centre!,
        radius: zone.radiusMetres!,
        fillColor: Color(zone.color).withOpacity(zone.comingSoon ? 0.05 : 0.2),
        strokeColor: zone.comingSoon
            ? Colors.grey.withOpacity(0.5)
            : Color(zone.color),
        strokeWidth: zone.comingSoon ? 1 : 2,
        onTap: () => _showZoneInfo(zone),
      ));
    }
  }

  void _listenToLocation() {
    _locationSub = FlutterBackgroundService().on('location').listen((event) {
      if (event != null && mounted) {
        final lat = event['lat'] as double;
        final lng = event['lng'] as double;
        setState(() => _currentPosition = LatLng(lat, lng));
      }
    });
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 16),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 16),
        );
      }
    } catch (_) {}
  }

  void _showZoneInfo(ZoneInfo zone) {
    final isPremium = ref.read(isPremiumProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ZoneInfoSheet(
        zone: zone,
        isPremium: isPremium,
      ),
    );
  }

  void _showZoneList() {
    final isPremium = ref.read(isPremiumProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ZoneListSheet(isPremium: isPremium),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showZones = _zoom >= 9.0;

    // Region markers for low zoom
    final Set<Marker> markers = showZones
        ? {}
        : _regions
            .map((r) => Marker(
                  markerId: MarkerId(r.name),
                  position: r.position,
                  infoWindow: InfoWindow(
                    title: r.name,
                    snippet: '${r.count} zone${r.count == 1 ? '' : 's'}',
                  ),
                ))
            .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone Map'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _londonCenter,
              zoom: 10,
            ),
            onMapCreated: (c) => _mapController = c,
            onCameraMove: (pos) {
              if ((pos.zoom - _zoom).abs() > 0.5) {
                setState(() => _zoom = pos.zoom);
              }
            },
            polygons: showZones ? _polygons : {},
            circles: showZones ? _circles : {},
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Zone list FAB
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'zones',
              onPressed: _showZoneList,
              tooltip: 'Zone list',
              child: const Icon(Icons.list),
            ),
          ),

          // Go to current location
          Positioned(
            bottom: 72,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Reset to London view
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'london',
              onPressed: () => _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(_londonCenter, 10),
              ),
              child: const Icon(Icons.zoom_out_map),
            ),
          ),

          // Zoom hint at low zoom
          if (!showZones)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Zoom in to see zone boundaries',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegionMarker {
  const _RegionMarker(this.name, this.position, this.count);
  final String name;
  final LatLng position;
  final int count;
}

// ---------------------------------------------------------------------------
// Zone info bottom sheet
// ---------------------------------------------------------------------------
class _ZoneInfoSheet extends StatelessWidget {
  const _ZoneInfoSheet({required this.zone, required this.isPremium});

  final ZoneInfo zone;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final bool locked = zone.proOnly && !isPremium;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Color(zone.color),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  zone.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (zone.comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Coming soon',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                )
              else if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.premium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('PRO',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(zone.description,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if (zone.operatingHours != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(zone.operatingHours!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (!zone.comingSoon)
            if (locked)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to subscription screen via context
                    context.push('/subscription');
                  },
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Upgrade to Pro to unlock UK alerts'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.premium),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: zone.payUrl.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse(zone.payUrl),
                          mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Pay now →'),
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zone list bottom sheet
// ---------------------------------------------------------------------------
class _ZoneListSheet extends StatelessWidget {
  const _ZoneListSheet({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ZoneInfo>>{
      '🔴 London': LondonZones.all,
      '🔵 Midlands': [UkZones.birmingham, UkZones.m6TollNorth, UkZones.m6TollSouth],
      '🔵 South West': [UkZones.bath],
      '🔵 South': [UkZones.portsmouth],
      '🔵 North': [UkZones.bradford, UkZones.sheffield],
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('All Zones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(entry.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  for (final zone in entry.value)
                    _ZoneListTile(zone: zone, isPremium: isPremium),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneListTile extends StatelessWidget {
  const _ZoneListTile({required this.zone, required this.isPremium});

  final ZoneInfo zone;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final bool locked = zone.proOnly && !isPremium;
    final String priceLabel = zone.comingSoon
        ? 'Coming soon'
        : zone.dailyCharge == 0.0
            ? 'Free'
            : '£${zone.dailyCharge.toStringAsFixed(2)}${zone.isCrossing ? '/crossing' : '/day'}';

    return ListTile(
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Color(zone.color),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Row(
        children: [
          Text(zone.shortName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(zone.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          if (locked)
            const Icon(Icons.lock, size: 14, color: AppColors.premium),
        ],
      ),
      subtitle: Text(priceLabel,
          style: TextStyle(
              fontSize: 12,
              color: zone.comingSoon ? Colors.grey : AppColors.danger)),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        // Fly to zone centre
        final centre = zone.centre ??
            (zone.polygon.isNotEmpty ? _centroid(zone.polygon) : null);
        if (centre != null) {
          // Can't directly access map controller from here, so we just close the sheet
        }
      },
    );
  }

  LatLng _centroid(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }
}
