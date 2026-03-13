import 'package:flutter/widgets.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// Displays information about the currently selected shape.
class ShapeInfoPanel extends StatefulWidget {
  final DrawingState drawingState;

  /// Whether to show coordinate list.
  final bool showCoordinates;

  /// Whether to show area/perimeter.
  final bool showMeasurements;

  /// Whether to show metadata entries.
  final bool showMetadata;

  const ShapeInfoPanel({
    super.key,
    required this.drawingState,
    this.showCoordinates = true,
    this.showMeasurements = true,
    this.showMetadata = true,
  });

  @override
  State<ShapeInfoPanel> createState() => _ShapeInfoPanelState();
}

class _ShapeInfoPanelState extends State<ShapeInfoPanel> {
  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ShapeInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawingState != widget.drawingState) {
      oldWidget.drawingState.removeListener(_onChanged);
      widget.drawingState.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.drawingState.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.drawingState.selectedShape;
    if (shape == null) return const SizedBox.shrink();

    final entries = <Widget>[];

    // Type & ID
    entries.add(_InfoRow(label: 'Type', value: shape.type.name));
    entries.add(_InfoRow(
      label: 'ID',
      value: shape.id.substring(0, 8),
    ));

    // Vertex count
    entries.add(_InfoRow(
      label: 'Vertices',
      value: '${shape.allPoints.length}',
    ));

    // Measurements
    if (widget.showMeasurements) {
      final area = GeometryUtils.shapeArea(shape);
      final perimeter = GeometryUtils.shapePerimeter(shape);
      if (area > 0) {
        entries.add(_InfoRow(label: 'Area', value: _formatArea(area)));
      }
      if (perimeter > 0) {
        entries.add(_InfoRow(
          label: 'Perimeter',
          value: _formatDistance(perimeter),
        ));
      }
    }

    // Circle-specific
    if (shape is DrawableCircle) {
      entries.add(_InfoRow(
        label: 'Radius',
        value: _formatDistance(shape.radiusMeters),
      ));
    }

    // Holes count for polygons
    if (shape is DrawablePolygon && shape.holes.isNotEmpty) {
      entries.add(_InfoRow(
        label: 'Holes',
        value: '${shape.holes.length}',
      ));
    }

    // Metadata
    if (widget.showMetadata && shape.metadata.isNotEmpty) {
      for (final e in shape.metadata.entries) {
        entries.add(_InfoRow(label: e.key, value: e.value));
      }
    }

    // Coordinates
    if (widget.showCoordinates) {
      entries.add(const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          'Coordinates',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF666666),
          ),
        ),
      ));
      for (var i = 0; i < shape.allPoints.length; i++) {
        final p = shape.allPoints[i];
        entries.add(Text(
          '  [$i] ${p.latitude.toStringAsFixed(6)}, '
          '${p.longitude.toStringAsFixed(6)}',
          style: const TextStyle(
            fontSize: 9,
            fontFamily: 'monospace',
            color: Color(0xFF444444),
          ),
        ));
      }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF0FFFFFF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries,
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(1)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatArea(double sqMeters) {
    if (sqMeters < 10000) return '${sqMeters.toStringAsFixed(1)} m²';
    final hectares = sqMeters / 10000;
    if (hectares < 100) return '${hectares.toStringAsFixed(2)} ha';
    return '${(sqMeters / 1e6).toStringAsFixed(2)} km²';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF333333),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
