import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';
import 'package:latlong2/latlong.dart';

/// Demonstrates GeoJSON export and import with live editing.
class GeoJsonPage extends StatefulWidget {
  const GeoJsonPage({super.key});

  @override
  State<GeoJsonPage> createState() => _GeoJsonPageState();
}

class _GeoJsonPageState extends State<GeoJsonPage> {
  final _state = DrawingState();
  final _layerKey = GlobalKey<DrawingLayerState>();
  final _jsonController = TextEditingController();
  var _showEditor = false;

  @override
  void initState() {
    super.initState();
    _seedShapes();
    _state.addListener(_rebuild);
  }

  void _seedShapes() {
    _state.addShape(const DrawablePolygon(
      id: 'geojson-demo',
      points: [
        LatLng(51.513, -0.135),
        LatLng(51.516, -0.127),
        LatLng(51.513, -0.118),
        LatLng(51.510, -0.125),
      ],
      metadata: {'name': 'Hyde Park Corner', 'category': 'park'},
      style: ShapeStylePresets.defaultWithStates,
    ));
    _state.addShape(const DrawableCircle(
      id: 'geojson-circle',
      center: LatLng(51.508, -0.120),
      radiusMeters: 300,
      metadata: {'name': 'Observation Zone'},
      style: ShapeStyle(
        fillColor: Color(0xFFE91E63),
        borderColor: Color(0xFFC2185B),
      ),
    ));
  }

  @override
  void dispose() {
    _state.removeListener(_rebuild);
    _jsonController.dispose();
    _state.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _exportGeoJson() {
    final json = GeoJsonUtils.toGeoJsonString(_state.shapes, pretty: true);
    _jsonController.text = json;
    setState(() => _showEditor = true);
  }

  void _importGeoJson() {
    try {
      final shapes = GeoJsonUtils.fromGeoJsonString(_jsonController.text);
      _state.clearAll();
      for (final shape in shapes) {
        _state.addShape(shape);
      }
      setState(() => _showEditor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${shapes.length} shapes')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid GeoJSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoJSON Import / Export'),
        actions: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Export'),
            onPressed: _state.shapes.isEmpty ? null : _exportGeoJson,
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Import'),
            onPressed: !_showEditor ? null : _importGeoJson,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: _showEditor ? 1 : 2,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: const LatLng(51.511, -0.128),
                    initialZoom: 15,
                    onTap: (_, latlng) =>
                        _layerKey.currentState?.handleTap(latlng),
                    onSecondaryTap: (_, latlng) =>
                        _layerKey.currentState?.handleSecondaryTap(latlng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    DrawingLayer(key: _layerKey, drawingState: _state),
                  ],
                ),
                // Shape count badge
                Positioned(
                  left: 12,
                  top: 12,
                  child: Chip(
                    avatar: const Icon(Icons.layers, size: 16),
                    label: Text('${_state.shapes.length} shapes'),
                  ),
                ),
                // Draw mode selector
                Positioned(
                  right: 12,
                  top: 12,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _modeIcon(DrawingMode.none, Icons.pan_tool_alt, 'Pan'),
                          _modeIcon(
                              DrawingMode.polygon, Icons.pentagon, 'Polygon'),
                          _modeIcon(
                              DrawingMode.polyline, Icons.timeline, 'Line'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showEditor) ...[
            const Divider(height: 1),
            Expanded(
              child: Container(
                color: theme.colorScheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.data_object, size: 16),
                          const SizedBox(width: 6),
                          Text('GeoJSON Editor',
                              style: theme.textTheme.labelLarge),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _showEditor = false),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: TextField(
                          controller: _jsonController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                            hintText: 'Paste GeoJSON here…',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeIcon(DrawingMode mode, IconData icon, String tip) {
    final active = _state.activeMode == mode;
    return IconButton(
      icon: Icon(icon, color: active ? Colors.blue : null),
      tooltip: tip,
      onPressed: () => _state.setMode(mode),
    );
  }
}
