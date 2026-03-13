import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:flutter_map_utils/src/drawing_tools/base_draw_tool.dart';
import 'package:flutter_map_utils/src/fm_extensions.dart';

/// A drawing tool for creating rectangles.
///
/// Two taps define opposite corners. A preview rectangle is shown after the
/// first tap. The result is a [DrawableRectangle] (4-point polygon).
class RectangleDrawTool extends BaseDrawTool {
  /// Style override for the preview rectangle.
  final ShapeStyle? previewStyle;

  const RectangleDrawTool({
    super.key,
    required super.drawingState,
    super.onDrawingComplete,
    super.showEdgeLengths,
    this.previewStyle,
  }) : super(showAreaPreview: true, autoCloseThreshold: 0);

  @override
  State<RectangleDrawTool> createState() => _RectangleDrawToolState();
}

class _RectangleDrawToolState extends BaseDrawToolState<RectangleDrawTool> {
  /// Tracks the hover/move position for live preview after first tap.
  LatLng? _hoverPoint;

  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(RectangleDrawTool oldWidget) {
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

  /// Update the hover position for live preview.
  void updateHoverPoint(LatLng? point) {
    if (_hoverPoint != point) {
      _hoverPoint = point;
      if (mounted) setState(() {});
    }
  }

  @override
  void handleTap(LatLng point) {
    final points = widget.drawingState.drawingPoints;

    if (points.isEmpty) {
      // First corner
      widget.drawingState.addDrawingPoint(point);
    } else {
      // Second corner → finish
      widget.drawingState.addDrawingPoint(point);
      finishDrawing();
    }
  }

  @override
  void finishDrawing() {
    final shape = widget.drawingState.finishDrawing(
      style: widget.previewStyle,
    );
    _hoverPoint = null;
    if (shape != null) {
      widget.onDrawingComplete?.call();
    }
  }

  @override
  void cancelDrawing() {
    _hoverPoint = null;
    super.cancelDrawing();
  }

  @override
  List<Widget> buildPreviewLayers(BuildContext context, MapCamera camera) {
    final points = widget.drawingState.drawingPoints;
    if (points.isEmpty) return const [];

    final style = widget.previewStyle ?? widget.drawingState.defaultStyle;
    final resolved = style.resolve();
    final layers = <Widget>[];

    final corner1 = points.first;
    final corner2 = _hoverPoint ?? (points.length >= 2 ? points.last : null);

    if (corner2 != null) {
      // Build the 4 corners of the rectangle
      final rectPoints = _buildRectPoints(corner1, corner2);

      layers.add(PolygonLayer(
        polygons: [
          Polygon(
            points: rectPoints,
            color: resolved.fillColor
                .withValues(alpha: resolved.fillOpacity),
            borderStrokeWidth: resolved.borderWidth,
            borderColor: resolved.borderColor,
              pattern: resolved.strokeType.toStrokePattern(),
          ),
        ],
      ));

      // Edge length labels
      final markers = buildEdgeLengthMarkers([...rectPoints, rectPoints.first]);
      if (markers.isNotEmpty) {
        layers.add(MarkerLayer(markers: markers));
      }

      // Area preview
      final areaMarker = buildAreaPreviewMarker(rectPoints);
      if (areaMarker != null) {
        layers.add(MarkerLayer(markers: [areaMarker]));
      }
    }

    // Corner markers
    layers.add(MarkerLayer(
      markers: [
        Marker(
          point: corner1,
          width: 14,
          height: 14,
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5722),
                border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
              ),
            ),
          ),
        ),
        if (corner2 != null)
          Marker(
            point: corner2,
            width: 14,
            height: 14,
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2196F3),
                  border:
                      Border.all(color: const Color(0xFFFFFFFF), width: 2),
                ),
              ),
            ),
          ),
      ],
    ));

    return layers;
  }

  /// Build 4 corner points from 2 opposite corners.
  List<LatLng> _buildRectPoints(LatLng c1, LatLng c2) {
    return [
      c1,
      LatLng(c1.latitude, c2.longitude),
      c2,
      LatLng(c2.latitude, c1.longitude),
    ];
  }
}
