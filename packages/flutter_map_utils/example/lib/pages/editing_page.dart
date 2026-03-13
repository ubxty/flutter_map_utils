import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';
import 'package:latlong2/latlong.dart';

/// Demonstrates shape selection, vertex editing, midpoint insertion,
/// vertex deletion, and whole-shape dragging.
class EditingPage extends StatefulWidget {
  const EditingPage({super.key});

  @override
  State<EditingPage> createState() => _EditingPageState();
}

class _EditingPageState extends State<EditingPage> {
  final _state = DrawingState();
  final _layerKey = GlobalKey<DrawingLayerState>();

  @override
  void initState() {
    super.initState();
    _seedShapes();
    _state.addListener(_rebuild);
  }

  /// Pre-populate sample shapes so the user has something to edit immediately.
  void _seedShapes() {
    _state.addShape(const DrawablePolygon(
      id: 'demo-polygon',
      points: [
        LatLng(51.512, -0.133),
        LatLng(51.515, -0.125),
        LatLng(51.511, -0.120),
        LatLng(51.508, -0.128),
      ],
      style: ShapeStylePresets.defaultWithStates,
    ));
    _state.addShape(const DrawablePolyline(
      id: 'demo-polyline',
      points: [
        LatLng(51.505, -0.135),
        LatLng(51.507, -0.130),
        LatLng(51.504, -0.122),
        LatLng(51.506, -0.115),
      ],
      style: ShapeStyle(
        fillColor: Color(0xFF4CAF50),
        borderColor: Color(0xFF388E3C),
        borderWidth: 3,
      ),
    ));
    _state.addShape(DrawableRectangle.fromCorners(
      id: 'demo-rect',
      corner1: const LatLng(51.500, -0.140),
      corner2: const LatLng(51.503, -0.132),
      style: const ShapeStyle(
        fillColor: Color(0xFFFF9800),
        borderColor: Color(0xFFF57C00),
      ),
    ));
    _state.addShape(const DrawableCircle(
      id: 'demo-circle',
      center: LatLng(51.502, -0.118),
      radiusMeters: 200,
      style: ShapeStyle(
        fillColor: Color(0xFF9C27B0),
        borderColor: Color(0xFF7B1FA2),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _state.selectedShape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editing & Selection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _state.canUndo ? _state.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _state.canRedo ? _state.redo : null,
          ),
          if (selected != null)
            IconButton(
              icon: const Icon(Icons.content_copy),
              tooltip: 'Duplicate',
              onPressed: () => _state.duplicateSelected(),
            ),
          if (selected != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _state.removeSelected,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(51.507, -0.128),
              initialZoom: 15,
              onTap: (_, latlng) => _layerKey.currentState?.handleTap(latlng),
              onSecondaryTap: (_, latlng) =>
                  _layerKey.currentState?.handleSecondaryTap(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              DrawingLayer(key: _layerKey, drawingState: _state),
              SelectionLayer(drawingState: _state),
              EditableShapeLayer(
                drawingState: _state,
                debugShowVertexIndices: true,
              ),
              ShapeDragger(drawingState: _state),
            ],
          ),
          // Info panel
          if (selected != null)
            Positioned(
              top: 12,
              right: 12,
              child: SizedBox(
                width: 260,
                child: Card(
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ShapeInfoPanel(drawingState: _state),
                  ),
                ),
              ),
            ),
          // Hint
          Positioned(
            left: 12,
            top: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Editing Controls', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _hint(Icons.touch_app, 'Tap shape to select'),
                    _hint(Icons.open_with, 'Drag vertex to move'),
                    _hint(Icons.add_circle_outline, 'Tap midpoint to insert'),
                    _hint(Icons.remove_circle_outline, 'Long-press vertex to delete'),
                    _hint(Icons.pan_tool, 'Drag shape to reposition'),
                  ],
                ),
              ),
            ),
          ),
          // Bottom status
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(230),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                selected != null
                    ? 'Selected: ${selected.type.name} (${selected.id.substring(0, 8)}…)'
                    : '${_state.shapes.length} shapes  •  Tap a shape to select and edit',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
