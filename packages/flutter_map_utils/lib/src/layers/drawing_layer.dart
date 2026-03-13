import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:flutter_map_utils/src/drawing_tools/freehand_draw_tool.dart';
import 'package:flutter_map_utils/src/drawing_tools/polygon_draw_tool.dart';
import 'package:flutter_map_utils/src/drawing_tools/polyline_draw_tool.dart';
import 'package:flutter_map_utils/src/drawing_tools/rectangle_draw_tool.dart';
import 'package:flutter_map_utils/src/drawing_tools/circle_draw_tool.dart';
import 'package:flutter_map_utils/src/fm_extensions.dart';

/// The main drawing layer widget.
///
/// Place this as a child of [FlutterMap]. It manages the active drawing tool
/// preview, routes map tap events, and renders committed shapes.
///
/// Wire map tap events from [MapOptions] into [DrawingLayerState.handleTap]:
/// ```dart
/// final layerKey = GlobalKey<DrawingLayerState>();
///
/// FlutterMap(
///   options: MapOptions(
///     onTap: (pos, latlng) => layerKey.currentState?.handleTap(latlng),
///     onSecondaryTap: (pos, latlng) =>
///         layerKey.currentState?.handleSecondaryTap(latlng),
///     onPointerHover: (event, latlng) =>
///         layerKey.currentState?.handlePointerHover(latlng),
///   ),
///   children: [
///     TileLayer(...),
///     DrawingLayer(key: layerKey, drawingState: state),
///   ],
/// )
/// ```
class DrawingLayer extends StatefulWidget {
  /// The drawing state.
  final DrawingState drawingState;

  /// Whether to show edge length labels while drawing.
  final bool showEdgeLengths;

  /// Whether to show live area preview while drawing.
  final bool showAreaPreview;

  /// Auto-close threshold in logical pixels.
  final double autoCloseThreshold;

  /// Style for the active drawing preview (overrides default).
  final ShapeStyle? previewStyle;

  /// Style overrides for selected committed shapes.
  final ShapeStyle? selectedStyle;

  /// Whether to render committed shapes. Set to false if you manage
  /// shape rendering separately.
  final bool renderCommittedShapes;

  /// Called when drawing finishes (shape committed).
  final VoidCallback? onDrawingComplete;

  /// Freehand simplification tolerance in meters.
  final double freehandSimplificationTolerance;

  /// Whether freehand closes as polygon (true) or stays as polyline (false).
  final bool freehandCloseAsPolygon;

  const DrawingLayer({
    super.key,
    required this.drawingState,
    this.showEdgeLengths = true,
    this.showAreaPreview = true,
    this.autoCloseThreshold = 15.0,
    this.previewStyle,
    this.selectedStyle,
    this.renderCommittedShapes = true,
    this.onDrawingComplete,
    this.freehandSimplificationTolerance = 5.0,
    this.freehandCloseAsPolygon = true,
  });

  @override
  State<DrawingLayer> createState() => DrawingLayerState();
}

/// State for [DrawingLayer].
///
/// Exposes [handleTap], [handleSecondaryTap], [handleLongPress],
/// [handlePointerHover], [finishDrawing], and [cancelDrawing] for
/// external wiring into [MapOptions] callbacks.
class DrawingLayerState extends State<DrawingLayer> {
  static const Distance _haversine = Distance();

  /// Hover position for live rectangle / circle preview.
  LatLng? _hoverPoint;

  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(DrawingLayer oldWidget) {
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

  // -- Public API for wiring into MapOptions --

  /// Route a map tap to the active drawing tool.
  void handleTap(LatLng point) {
    final state = widget.drawingState;
    switch (state.activeMode) {
      case DrawingMode.polygon:
        _handlePolygonTap(point);
      case DrawingMode.polyline:
        state.addDrawingPoint(point);
      case DrawingMode.rectangle:
        _handleRectangleTap(point);
      case DrawingMode.circle:
        _handleCircleTap(point);
      case DrawingMode.freehand:
        break; // Pointer events handled by FreehandDrawTool widget
      case DrawingMode.hole:
        state.addDrawingPoint(point);
      case DrawingMode.measure:
        state.addDrawingPoint(point);
      case DrawingMode.select:
      case DrawingMode.none:
        break;
    }
  }

  /// Finish drawing on secondary tap (right-click / two-finger tap).
  void handleSecondaryTap(LatLng point) {
    if (widget.drawingState.isDrawing) finishDrawing();
  }

  /// Finish drawing on long press.
  void handleLongPress(LatLng point) {
    if (widget.drawingState.isDrawing) finishDrawing();
  }

  /// Update hover point for live preview (rect / circle modes).
  void handlePointerHover(LatLng point) {
    final mode = widget.drawingState.activeMode;
    if (mode == DrawingMode.rectangle || mode == DrawingMode.circle) {
      _hoverPoint = point;
      setState(() {});
    }
  }

  /// Finish the active drawing operation.
  void finishDrawing() {
    final state = widget.drawingState;
    switch (state.activeMode) {
      case DrawingMode.polygon:
      case DrawingMode.polyline:
      case DrawingMode.rectangle:
      case DrawingMode.freehand:
        final shape = state.finishDrawing(style: widget.previewStyle);
        _hoverPoint = null;
        if (shape != null) widget.onDrawingComplete?.call();
      case DrawingMode.circle:
        _finishCircle();
      case DrawingMode.hole:
        state.finishHoleDrawing();
      default:
        break;
    }
  }

  /// Cancel the active drawing.
  void cancelDrawing() {
    _hoverPoint = null;
    widget.drawingState.cancelDrawing();
  }

  // -- Private tap routing --

  void _handlePolygonTap(LatLng point) {
    final state = widget.drawingState;
    final points = state.drawingPoints;

    // Auto-close check
    if (points.length >= 3 && widget.autoCloseThreshold > 0) {
      final camera = MapCamera.of(context);
      final screenPoint = camera.latLngToScreenOffset(point);
      final screenFirst = camera.latLngToScreenOffset(points.first);
      final dx = screenPoint.dx - screenFirst.dx;
      final dy = screenPoint.dy - screenFirst.dy;
      if ((dx * dx + dy * dy) <=
          widget.autoCloseThreshold * widget.autoCloseThreshold) {
        finishDrawing();
        return;
      }
    }

    state.addDrawingPoint(point);
  }

  void _handleRectangleTap(LatLng point) {
    final state = widget.drawingState;
    if (state.drawingPoints.isEmpty) {
      state.addDrawingPoint(point);
    } else {
      state.addDrawingPoint(point);
      finishDrawing();
    }
  }

  void _handleCircleTap(LatLng point) {
    final state = widget.drawingState;
    if (state.circleCenter == null) {
      state.setCircleCenter(point);
    } else {
      final radius = _haversine.distance(state.circleCenter!, point);
      if (radius > 0) {
        final shape = state.finishCircleDrawing(
          radius,
          style: widget.previewStyle,
        );
        _hoverPoint = null;
        if (shape != null) widget.onDrawingComplete?.call();
      }
    }
  }

  void _finishCircle() {
    final state = widget.drawingState;
    if (state.circleCenter != null && _hoverPoint != null) {
      final radius =
          _haversine.distance(state.circleCenter!, _hoverPoint!);
      if (radius > 0) {
        final shape = state.finishCircleDrawing(
          radius,
          style: widget.previewStyle,
        );
        _hoverPoint = null;
        if (shape != null) widget.onDrawingComplete?.call();
      }
    }
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    final mode = widget.drawingState.activeMode;
    final layers = <Widget>[];

    // Render committed shapes
    if (widget.renderCommittedShapes) {
      layers.addAll(_buildCommittedShapeLayers());
    }

    // Active drawing tool preview
    switch (mode) {
      case DrawingMode.polygon:
        layers.add(PolygonDrawTool(
          drawingState: widget.drawingState,
          previewStyle: widget.previewStyle,
          showEdgeLengths: widget.showEdgeLengths,
          showAreaPreview: widget.showAreaPreview,
          autoCloseThreshold: widget.autoCloseThreshold,
        ));
      case DrawingMode.polyline:
        layers.add(PolylineDrawTool(
          drawingState: widget.drawingState,
          previewStyle: widget.previewStyle,
          showEdgeLengths: widget.showEdgeLengths,
        ));
      case DrawingMode.rectangle:
        layers.add(RectangleDrawTool(
          drawingState: widget.drawingState,
          previewStyle: widget.previewStyle,
          showEdgeLengths: widget.showEdgeLengths,
        ));
      case DrawingMode.circle:
        layers.add(CircleDrawTool(
          drawingState: widget.drawingState,
          previewStyle: widget.previewStyle,
        ));
      case DrawingMode.freehand:
        layers.add(FreehandDrawTool(
          drawingState: widget.drawingState,
          previewStyle: widget.previewStyle,
          closeAsPolygon: widget.freehandCloseAsPolygon,
          simplificationTolerance: widget.freehandSimplificationTolerance,
          onDrawingComplete: widget.onDrawingComplete,
        ));
      case DrawingMode.hole:
        layers.addAll(_buildHolePreviewLayers());
      default:
        break;
    }

    if (layers.isEmpty) return const SizedBox.shrink();
    return Stack(children: layers);
  }

  /// Build flutter_map layers for all committed shapes.
  List<Widget> _buildCommittedShapeLayers() {
    final shapes = widget.drawingState.shapes;
    if (shapes.isEmpty) return const [];

    final selectedId = widget.drawingState.selectedShapeId;
    final polygons = <Polygon>[];
    final polylines = <Polyline>[];
    final circles = <CircleMarker>[];
    final layers = <Widget>[];

    for (final shape in shapes) {
      final isSelected = shape.id == selectedId;
      final style = isSelected
          ? (widget.selectedStyle ?? shape.style.resolve(selected: true))
          : shape.style.resolve();

      switch (shape) {
        case final DrawablePolygon s:
          polygons.add(Polygon(
            points: s.points,
            holePointsList: s.holes.isEmpty ? null : s.holes,
            color: style.fillColor.withValues(alpha: style.fillOpacity),
            borderStrokeWidth: style.borderWidth,
            borderColor: style.borderColor,
            pattern: style.strokeType.toStrokePattern(),
          ));
        case final DrawablePolyline s:
          polylines.add(Polyline(
            points: s.points,
            strokeWidth: style.borderWidth,
            color: style.borderColor,
            pattern: style.strokeType.toStrokePattern(),
          ));
        case final DrawableCircle s:
          circles.add(CircleMarker(
            point: s.center,
            radius: s.radiusMeters,
            useRadiusInMeter: true,
            color: style.fillColor.withValues(alpha: style.fillOpacity),
            borderStrokeWidth: style.borderWidth,
            borderColor: style.borderColor,
          ));
        case final DrawableRectangle s:
          polygons.add(Polygon(
            points: s.points,
            color: style.fillColor.withValues(alpha: style.fillOpacity),
            borderStrokeWidth: style.borderWidth,
            borderColor: style.borderColor,
            pattern: style.strokeType.toStrokePattern(),
          ));
      }
    }

    if (polygons.isNotEmpty) {
      layers.add(PolygonLayer(polygons: polygons));
    }
    if (polylines.isNotEmpty) {
      layers.add(PolylineLayer(polylines: polylines));
    }
    if (circles.isNotEmpty) {
      layers.add(CircleLayer(circles: circles));
    }

    return layers;
  }

  /// Build preview layers for hole drawing mode.
  List<Widget> _buildHolePreviewLayers() {
    final points = widget.drawingState.drawingPoints;
    if (points.isEmpty) return const [];

    final layers = <Widget>[];

    if (points.length >= 2) {
      layers.add(PolylineLayer(
        polylines: [
          Polyline(
            points: points,
            strokeWidth: 2,
            color: const Color(0xFFE53935),
            pattern: StrokePattern.dashed(segments: const [8, 4]),
          ),
        ],
      ));
    }

    layers.add(MarkerLayer(
      markers: [
        for (final p in points)
          Marker(
            point: p,
            width: 10,
            height: 10,
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE53935),
                  border:
                      Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
                ),
              ),
            ),
          ),
      ],
    ));

    return layers;
  }
}
