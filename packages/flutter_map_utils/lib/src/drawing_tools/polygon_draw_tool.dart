import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:flutter_map_utils/src/drawing_tools/base_draw_tool.dart';
import 'package:flutter_map_utils/src/fm_extensions.dart';

/// A drawing tool for creating polygons by tapping vertices.
///
/// Shows a polyline preview during drawing, fills with polygon preview
/// when >= 3 points. Finish via [finishDrawing], double-tap, or
/// auto-close (tap near first vertex).
///
/// Place as a child of [FlutterMap.children]:
/// ```dart
/// FlutterMap(
///   children: [
///     TileLayer(...),
///     PolygonDrawTool(drawingState: state),
///   ],
/// )
/// ```
class PolygonDrawTool extends BaseDrawTool {
  /// Style override for the preview polygon. Falls back to
  /// [DrawingState.defaultStyle].
  final ShapeStyle? previewStyle;

  /// Minimum number of points required to form a valid polygon.
  final int minPoints;

  const PolygonDrawTool({
    super.key,
    required super.drawingState,
    super.onDrawingComplete,
    super.showEdgeLengths,
    super.showAreaPreview,
    super.autoCloseThreshold,
    this.previewStyle,
    this.minPoints = 3,
  });

  @override
  State<PolygonDrawTool> createState() => _PolygonDrawToolState();
}

class _PolygonDrawToolState extends BaseDrawToolState<PolygonDrawTool> {
  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(PolygonDrawTool oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawingState != widget.drawingState) {
      oldWidget.drawingState.removeListener(_onStateChanged);
      widget.drawingState.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.drawingState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void handleTap(LatLng point) {
    final points = widget.drawingState.drawingPoints;

    // Auto-close: if close to first vertex and enough points
    if (points.length >= widget.minPoints) {
      final camera = MapCamera.of(context);
      if (isNearFirstVertex(camera, point, points.first)) {
        finishDrawing();
        return;
      }
    }

    widget.drawingState.addDrawingPoint(point);
  }

  @override
  void finishDrawing() {
    final shape = widget.drawingState.finishDrawing(
      style: widget.previewStyle,
    );
    if (shape != null) {
      widget.onDrawingComplete?.call();
    }
  }

  @override
  List<Widget> buildPreviewLayers(BuildContext context, MapCamera camera) {
    final points = widget.drawingState.drawingPoints;
    if (points.isEmpty) return const [];

    final style = widget.previewStyle ?? widget.drawingState.defaultStyle;
    final resolved = style.resolve();
    final layers = <Widget>[];

    // Vertex markers
    layers.add(MarkerLayer(
      markers: [
        for (var i = 0; i < points.length; i++)
          Marker(
            point: points[i],
            width: 14,
            height: 14,
            child: _VertexDot(isFirst: i == 0, isAutoCloseHighlighted: false),
          ),
      ],
    ));

    if (points.length >= 2) {
      if (points.length >= widget.minPoints) {
        // Polygon preview (filled)
        layers.add(PolygonLayer(
          polygons: [
            Polygon(
              points: points,
              color: resolved.fillColor
                  .withValues(alpha: resolved.fillOpacity),
              borderStrokeWidth: resolved.borderWidth,
              borderColor: resolved.borderColor,
              pattern: resolved.strokeType.toStrokePattern(),
            ),
          ],
        ));
      } else {
        // Polyline preview (not enough points to close)
        layers.add(PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: resolved.borderWidth,
              color: resolved.borderColor,
              pattern: resolved.strokeType.toStrokePattern(),
            ),
          ],
        ));
      }

      // Edge length labels
      final markers = buildEdgeLengthMarkers(points);
      if (markers.isNotEmpty) {
        layers.add(MarkerLayer(markers: markers));
      }
    }

    // Area preview at centroid
    if (points.length >= widget.minPoints) {
      final areaMarker = buildAreaPreviewMarker(points);
      if (areaMarker != null) {
        layers.add(MarkerLayer(markers: [areaMarker]));
      }
    }

    // Auto-close indicator: highlight first vertex when close
    if (points.length >= widget.minPoints && widget.autoCloseThreshold > 0) {
      layers.add(MarkerLayer(
        markers: [
          Marker(
            point: points.first,
            width: 24,
            height: 24,
            child: const _AutoCloseIndicator(),
          ),
        ],
      ));
    }

    return layers;
  }
}

/// Small dot at each vertex.
class _VertexDot extends StatelessWidget {
  final bool isFirst;
  final bool isAutoCloseHighlighted;

  const _VertexDot({
    required this.isFirst,
    required this.isAutoCloseHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: isFirst ? 12 : 8,
        height: isFirst ? 12 : 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAutoCloseHighlighted
              ? const Color(0xFF4CAF50)
              : isFirst
                  ? const Color(0xFFFF5722)
                  : const Color(0xFF2196F3),
          border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
        ),
      ),
    );
  }
}

/// Pulsing circle around first vertex indicating auto-close is available.
class _AutoCloseIndicator extends StatelessWidget {
  const _AutoCloseIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF4CAF50),
            width: 2,
          ),
        ),
      ),
    );
  }
}
