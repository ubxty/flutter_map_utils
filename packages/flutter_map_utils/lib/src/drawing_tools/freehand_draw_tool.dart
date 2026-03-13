import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:flutter_map_utils/src/drawing_tools/base_draw_tool.dart';

/// A freehand drawing tool.
///
/// Captures points via pointer move events. On pointer-up, simplifies
/// the path via Douglas-Peucker and creates a polygon (auto-closed)
/// or polyline.
///
/// This tool uses a [Listener] to capture pointer events and locks
/// map panning during drawing.
class FreehandDrawTool extends BaseDrawTool {
  /// Style override for the preview shape.
  final ShapeStyle? previewStyle;

  /// Whether to auto-close the path into a polygon.
  final bool closeAsPolygon;

  /// Douglas-Peucker simplification tolerance in meters.
  /// Higher values produce fewer points. Set to 0 to disable.
  final double simplificationTolerance;

  /// Minimum number of points to keep after simplification.
  final int minPoints;

  /// Number of Chaikin corner-cutting iterations for smoothing.
  /// Higher values produce smoother curves. Set to 0 to disable.
  final int smoothingIterations;

  const FreehandDrawTool({
    super.key,
    required super.drawingState,
    super.onDrawingComplete,
    this.previewStyle,
    this.closeAsPolygon = true,
    this.simplificationTolerance = 5.0,
    this.minPoints = 4,
    this.smoothingIterations = 2,
  }) : super(
          showEdgeLengths: false,
          showAreaPreview: false,
          autoCloseThreshold: 0,
        );

  @override
  State<FreehandDrawTool> createState() => _FreehandDrawToolState();
}

class _FreehandDrawToolState extends BaseDrawToolState<FreehandDrawTool> {
  bool _isDrawing = false;
  final List<LatLng> _freehandPoints = [];

  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(FreehandDrawTool oldWidget) {
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
    // Freehand uses pointer events, not taps
  }

  void _handlePointerDown(PointerDownEvent event) {
    final camera = MapCamera.of(context);
    final point = camera.offsetToCrs(event.localPosition);
    _isDrawing = true;
    _freehandPoints.clear();
    _freehandPoints.add(point);
    widget.drawingState.beginShapeDrag(); // Lock map gestures
    setState(() {});
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDrawing) return;
    final camera = MapCamera.of(context);
    final point = camera.offsetToCrs(event.localPosition);
    _freehandPoints.add(point);
    setState(() {});
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isDrawing) return;
    _isDrawing = false;
    widget.drawingState.endShapeDrag();

    if (_freehandPoints.length >= widget.minPoints) {
      _finalizeFreehand();
    } else {
      _freehandPoints.clear();
    }
    setState(() {});
  }

  void _finalizeFreehand() {
    var points = GeometryUtils.simplifyPath(
      _freehandPoints,
      tolerance: widget.simplificationTolerance,
    );

    if (points.length < widget.minPoints) {
      points = List.of(_freehandPoints);
    }

    // Smooth the simplified path using Chaikin's corner-cutting
    if (widget.smoothingIterations > 0 && points.length >= 3) {
      points = GeometryUtils.smoothPath(
        points,
        iterations: widget.smoothingIterations,
        closed: widget.closeAsPolygon,
      );
    }

    // Push smoothed points to drawing state and finish
    for (final p in points) {
      widget.drawingState.addDrawingPoint(p);
    }
    finishDrawing();
    _freehandPoints.clear();
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
  void cancelDrawing() {
    _isDrawing = false;
    _freehandPoints.clear();
    widget.drawingState.endShapeDrag();
    super.cancelDrawing();
  }

  @override
  List<Widget> buildPreviewLayers(BuildContext context, MapCamera camera) {
    final points =
        _isDrawing ? _freehandPoints : widget.drawingState.drawingPoints;
    if (points.length < 2) return const [];

    final style = widget.previewStyle ?? widget.drawingState.defaultStyle;
    final resolved = style.resolve();

    return [
      PolylineLayer(
        polylines: [
          Polyline(
            points: points,
            strokeWidth: resolved.borderWidth,
            color: resolved.borderColor,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final layers = buildPreviewLayers(context, camera);

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Transparent overlay to capture gestures
          Positioned.fill(child: Container()),
          ...layers,
        ],
      ),
    );
  }

}
