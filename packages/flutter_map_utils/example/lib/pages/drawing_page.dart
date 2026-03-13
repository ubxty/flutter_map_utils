import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';
import 'package:latlong2/latlong.dart';

/// Demonstrates all drawing modes: polygon, polyline, rectangle, circle, freehand.
class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  final _state = DrawingState();
  final _layerKey = GlobalKey<DrawingLayerState>();

  @override
  void initState() {
    super.initState();
    _state.addListener(_rebuild);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing Tools'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _state.canUndo ? _state.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: _state.canRedo ? _state.redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all',
            onPressed: _state.shapes.isEmpty ? null : _state.clearAll,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(51.509, -0.128),
              initialZoom: 14,
              onTap: (_, latlng) => _layerKey.currentState?.handleTap(latlng),
              onSecondaryTap: (_, latlng) =>
                  _layerKey.currentState?.handleSecondaryTap(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              DrawingLayer(key: _layerKey, drawingState: _state),
            ],
          ),
          // Mode chips
          Positioned(
            left: 12,
            top: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mode', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    ..._modeChips(theme),
                  ],
                ),
              ),
            ),
          ),
          // Status bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(230),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _statusText(),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _modeChips(ThemeData theme) {
    const modes = [
      (DrawingMode.none, Icons.pan_tool_alt, 'Pan'),
      (DrawingMode.polygon, Icons.pentagon, 'Polygon'),
      (DrawingMode.polyline, Icons.timeline, 'Polyline'),
      (DrawingMode.rectangle, Icons.crop_square, 'Rectangle'),
      (DrawingMode.circle, Icons.circle_outlined, 'Circle'),
      (DrawingMode.freehand, Icons.gesture, 'Freehand'),
    ];

    return modes.map((entry) {
      final (mode, icon, label) = entry;
      final active = _state.activeMode == mode;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ChoiceChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          selected: active,
          onSelected: (_) => _state.setMode(mode),
        ),
      );
    }).toList();
  }

  String _statusText() {
    final count = _state.shapes.length;
    if (_state.isDrawing) {
      return 'Drawing ${_state.activeMode.name}  •  '
          '${_state.drawingPoints.length} points  •  '
          'Tap to add, right-click to finish';
    }
    return '$count shape${count == 1 ? '' : 's'}  •  '
        'Select a mode to start drawing';
  }
}
