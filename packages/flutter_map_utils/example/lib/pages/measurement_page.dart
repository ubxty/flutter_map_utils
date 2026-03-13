import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';
import 'package:latlong2/latlong.dart';

/// Demonstrates the measurement tool with distance and area calculations.
class MeasurementPage extends StatefulWidget {
  const MeasurementPage({super.key});

  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage> {
  final _measureState = MeasurementState();
  var _unit = MeasurementUnit.metric;

  @override
  void initState() {
    super.initState();
    _measureState.addListener(_rebuild);
  }

  @override
  void dispose() {
    _measureState.removeListener(_rebuild);
    _measureState.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _measureState.totalDistanceMeters;
    final area = _measureState.areaSquareMeters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement'),
        actions: [
          SegmentedButton<MeasurementUnit>(
            segments: const [
              ButtonSegment(value: MeasurementUnit.metric, label: Text('m/km')),
              ButtonSegment(value: MeasurementUnit.imperial, label: Text('ft/mi')),
            ],
            selected: {_unit},
            onSelectionChanged: (v) => setState(() => _unit = v.first),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.backspace),
            tooltip: 'Undo last point',
            onPressed:
                _measureState.isEmpty ? null : _measureState.undoLastPoint,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: _measureState.isEmpty ? null : _measureState.clear,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(51.509, -0.128),
              initialZoom: 14,
              onTap: (_, latlng) => _measureState.addPoint(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              MeasurementLayer(
                measurementState: _measureState,
                unit: _unit,
              ),
            ],
          ),
          // Summary card
          Positioned(
            top: 12,
            right: 12,
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Measurement',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _metric('Points', '${_measureState.pointCount}'),
                    _metric('Distance', _fmtDist(total)),
                    if (_measureState.pointCount >= 3)
                      _metric('Area', _fmtArea(area)),
                  ],
                ),
              ),
            ),
          ),
          // Hint
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(230),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Tap on the map to add measurement points',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _fmtDist(double meters) {
    if (_unit == MeasurementUnit.imperial) {
      final ft = meters * 3.28084;
      return ft < 5280
          ? '${ft.toStringAsFixed(0)} ft'
          : '${(ft / 5280).toStringAsFixed(2)} mi';
    }
    return meters < 1000
        ? '${meters.toStringAsFixed(1)} m'
        : '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _fmtArea(double sqm) {
    if (_unit == MeasurementUnit.imperial) {
      final sqft = sqm * 10.7639;
      return sqft < 43560
          ? '${sqft.toStringAsFixed(0)} ft²'
          : '${(sqft / 43560).toStringAsFixed(2)} ac';
    }
    return sqm < 10000
        ? '${sqm.toStringAsFixed(1)} m²'
        : '${(sqm / 10000).toStringAsFixed(2)} ha';
  }
}
