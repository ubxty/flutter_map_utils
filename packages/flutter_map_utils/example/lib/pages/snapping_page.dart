import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';
import 'package:latlong2/latlong.dart';

/// Demonstrates the snapping engine with visual feedback.
class SnappingPage extends StatefulWidget {
  const SnappingPage({super.key});

  @override
  State<SnappingPage> createState() => _SnappingPageState();
}

class _SnappingPageState extends State<SnappingPage> {
  final _state = DrawingState();
  final _layerKey = GlobalKey<DrawingLayerState>();

  // Snapping config
  var _snapEnabled = true;
  var _tolerance = 15.0;
  var _gridSpacing = 0.001;
  final _activePriorities = <SnapType>{
    SnapType.vertex,
    SnapType.midpoint,
    SnapType.edge,
  };

  SnapResult? _lastSnap;

  @override
  void initState() {
    super.initState();
    _seedShapes();
    _state.addListener(_rebuild);
  }

  void _seedShapes() {
    // A triangle to snap to
    _state.addShape(const DrawablePolygon(
      id: 'snap-poly',
      points: [
        LatLng(51.512, -0.130),
        LatLng(51.516, -0.122),
        LatLng(51.510, -0.118),
      ],
      style: ShapeStyle(
        fillColor: Color(0xFF2196F3),
        borderColor: Color(0xFF1565C0),
        borderWidth: 2,
      ),
    ));
    // A line to snap to
    _state.addShape(const DrawablePolyline(
      id: 'snap-line',
      points: [
        LatLng(51.508, -0.138),
        LatLng(51.514, -0.135),
        LatLng(51.517, -0.130),
      ],
      style: ShapeStyle(
        borderColor: Color(0xFFFF5722),
        borderWidth: 3,
      ),
    ));
  }

  @override
  void dispose() {
    _state.removeListener(_rebuild);
    _state.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _handleTap(LatLng latlng) {
    if (_snapEnabled) {
      final config = SnapConfig(
        enabled: true,
        toleranceMeters: _tolerance,
        priorities: _activePriorities.toList(),
        gridSpacing: _gridSpacing,
      );
      final result = SnappingEngine.findSnapTarget(
        latlng,
        _state.shapes,
        config,
      );
      setState(() => _lastSnap = result);
      if (result != null) {
        _layerKey.currentState?.handleTap(result.point);
        return;
      }
    }
    _layerKey.currentState?.handleTap(latlng);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snapping Engine'),
        actions: [
          Switch(
            value: _snapEnabled,
            onChanged: (v) => setState(() => _snapEnabled = v),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _state.canUndo ? _state.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear drawn',
            onPressed: () {
              // Keep seed shapes, remove others
              final toRemove = _state.shapes
                  .where((s) => !s.id.startsWith('snap-'))
                  .toList();
              for (final s in toRemove) {
                _state.removeShape(s.id);
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Config panel
          SizedBox(
            width: 260,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text('Snap Config', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  Text('Tolerance: ${_tolerance.toStringAsFixed(0)} m',
                      style: theme.textTheme.bodySmall),
                  Slider(
                    value: _tolerance,
                    min: 5,
                    max: 50,
                    onChanged: (v) => setState(() => _tolerance = v),
                  ),
                  const SizedBox(height: 8),
                  Text('Grid spacing: ${_gridSpacing.toStringAsFixed(4)}°',
                      style: theme.textTheme.bodySmall),
                  Slider(
                    value: _gridSpacing,
                    min: 0.0001,
                    max: 0.01,
                    onChanged: (v) => setState(() => _gridSpacing = v),
                  ),
                  const Divider(),
                  Text('Snap Priorities', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final snapType in SnapType.values)
                    CheckboxListTile(
                      dense: true,
                      title: Text(snapType.name, style: const TextStyle(fontSize: 13)),
                      value: _activePriorities.contains(snapType),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _activePriorities.add(snapType);
                          } else {
                            _activePriorities.remove(snapType);
                          }
                        });
                      },
                    ),
                  const Divider(),
                  Text('Draw Mode', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _chip(DrawingMode.none, 'Pan'),
                      _chip(DrawingMode.polygon, 'Polygon'),
                      _chip(DrawingMode.polyline, 'Polyline'),
                    ],
                  ),
                  const Divider(),
                  if (_lastSnap != null) ...[
                    Text('Last Snap', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text('Type: ${_lastSnap!.type.name}',
                        style: theme.textTheme.bodySmall),
                    Text(
                      'Point: ${_lastSnap!.point.latitude.toStringAsFixed(5)}, '
                      '${_lastSnap!.point.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Distance: ${_lastSnap!.distance.toStringAsFixed(1)} m',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(51.512, -0.128),
                initialZoom: 15,
                onTap: (_, latlng) => _handleTap(latlng),
                onSecondaryTap: (_, latlng) =>
                    _layerKey.currentState?.handleSecondaryTap(latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                DrawingLayer(key: _layerKey, drawingState: _state),
                // Visual snap indicator
                if (_lastSnap != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _lastSnap!.point,
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withAlpha(120),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(DrawingMode mode, String label) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _state.activeMode == mode,
      onSelected: (_) => _state.setMode(mode),
    );
  }
}
