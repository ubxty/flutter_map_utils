import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:google_map_utils/src/drawing/gm_drawing_controller.dart';

/// Freehand drawing overlay for Google Maps.
///
/// Captures pointer events via a transparent overlay, collects screen
/// coordinates during the drag, renders a live preview via [CustomPaint],
/// and batch-converts to [LatLng] on pointer-up.
///
/// Place this as a sibling of [gm.GoogleMap] inside a [Stack]:
///
/// ```dart
/// Stack(
///   children: [
///     GoogleMap(...),
///     if (drawingState.activeMode == DrawingMode.freehand)
///       GmFreehandOverlay(controller: controller),
///   ],
/// )
/// ```
class GmFreehandOverlay extends StatefulWidget {
  /// The drawing controller (provides async coordinate conversion).
  final GmDrawingController controller;

  /// Style override for the preview stroke.
  final ShapeStyle? previewStyle;

  /// Whether to auto-close the path into a polygon.
  final bool closeAsPolygon;

  /// Douglas-Peucker simplification tolerance in meters.
  final double simplificationTolerance;

  /// Minimum number of points to keep after simplification.
  final int minPoints;

  /// Number of Chaikin corner-cutting iterations for smoothing.
  /// Defaults to 0 (no smoothing) to preserve shape fidelity.
  /// Set to 1–2 only for organic/freeform shapes where corner rounding is acceptable.
  final int smoothingIterations;

  /// Minimum distance in logical pixels between collected screen points.
  /// Filters redundant points during drawing to reduce the number of
  /// platform-channel calls on finalization. Default 4.0 px.
  final double minSampleDistance;

  /// Called when drawing is finalized (shape committed).
  final VoidCallback? onDrawingComplete;

  /// Notifier to trigger finalization from outside.
  /// Set value to `true` to finalize the current drawing.
  final ValueNotifier<bool>? finalizeNotifier;

  const GmFreehandOverlay({
    super.key,
    required this.controller,
    this.previewStyle,
    this.closeAsPolygon = true,
    this.simplificationTolerance = 20.0,
    this.minPoints = 4,
    this.smoothingIterations = 0,
    this.minSampleDistance = 4.0,
    this.onDrawingComplete,
    this.finalizeNotifier,
  });

  @override
  State<GmFreehandOverlay> createState() => _GmFreehandOverlayState();
}

class _GmFreehandOverlayState extends State<GmFreehandOverlay> {
  bool _isDrawing = false;
  final List<Offset> _screenPoints = [];
  final Set<int> _activePointers = {};
  int? _drawingPointer;

  @override
  void initState() {
    super.initState();
    widget.finalizeNotifier?.addListener(_onFinalizeRequested);
  }

  @override
  void didUpdateWidget(GmFreehandOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.finalizeNotifier != widget.finalizeNotifier) {
      oldWidget.finalizeNotifier?.removeListener(_onFinalizeRequested);
      widget.finalizeNotifier?.addListener(_onFinalizeRequested);
    }
  }

  @override
  void dispose() {
    widget.finalizeNotifier?.removeListener(_onFinalizeRequested);
    super.dispose();
  }

  void _onFinalizeRequested() {
    if (widget.finalizeNotifier?.value == true) {
      widget.finalizeNotifier?.value = false;
      _finishDrawing();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length == 1) {
      // Single finger — start drawing
      _drawingPointer = event.pointer;
      _isDrawing = true;
      _screenPoints.add(event.localPosition);
      widget.controller.drawingState.beginShapeDrag();
    }
    // Multi-touch: don't draw, let map handle zoom/pan
    setState(() {});
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDrawing || _activePointers.length > 1) return;
    if (event.pointer != _drawingPointer) return;
    final pos = event.localPosition;
    // Skip points closer than minSampleDistance to reduce finalization cost
    if (_screenPoints.isNotEmpty &&
        (pos - _screenPoints.last).distance < widget.minSampleDistance) {
      return;
    }
    _screenPoints.add(pos);
    setState(() {});
  }

  Future<void> _handlePointerUp(PointerUpEvent event) async {
    _activePointers.remove(event.pointer);
    if (event.pointer == _drawingPointer) {
      if (_isDrawing) {
        _isDrawing = false;
        widget.controller.drawingState.endShapeDrag();
      }
      _drawingPointer = null;
    }
    setState(() {});
  }

  /// Finalize the accumulated strokes into a polygon.
  Future<void> _finishDrawing() async {
    if (_screenPoints.length < widget.minPoints) {
      _screenPoints.clear();
      setState(() {});
      return;
    }

    await _finalizeFreehand();
    _screenPoints.clear();
    setState(() {});
  }

  Future<void> _finalizeFreehand() async {
    final controller = widget.controller;
    if (controller.mapController == null) return;

    // Batch-convert screen points to LatLng
    final latLngPoints = <LatLng>[];
    for (final sp in _screenPoints) {
      final ll = await controller.screenToLatLng(sp);
      if (ll != null) latLngPoints.add(ll);
    }

    if (latLngPoints.length < widget.minPoints) return;

    // Adaptive tolerance: use fraction of bounding box diagonal so
    // small drawings (buildings) still simplify properly
    final lats = latLngPoints.map((p) => p.latitude);
    final lngs = latLngPoints.map((p) => p.longitude);
    final latRange = lats.reduce(math.max) - lats.reduce(math.min);
    final lngRange = lngs.reduce(math.max) - lngs.reduce(math.min);
    final cosLat = math.cos(latLngPoints.first.latitude * math.pi / 180);
    final diagMeters = math.sqrt(
      math.pow(latRange * 111320, 2) +
      math.pow(lngRange * 111320 * cosLat, 2),
    );
    // 3% of diagonal, clamped between 0.5m and configured max
    final adaptiveTolerance = (diagMeters * 0.03).clamp(
      0.5, widget.simplificationTolerance,
    );

    var points = GeometryUtils.simplifyPath(
      latLngPoints,
      tolerance: adaptiveTolerance,
    );
    if (points.length < widget.minPoints) {
      points = List.of(latLngPoints);
    }

    // If still too many, increase tolerance progressively
    var tol = adaptiveTolerance;
    while (points.length > 30 && tol < diagMeters * 0.5) {
      tol *= 2;
      points = GeometryUtils.simplifyPath(latLngPoints, tolerance: tol);
    }

    // Smooth only when few points
    if (widget.smoothingIterations > 0 &&
        points.length >= 3 &&
        points.length <= 20) {
      points = GeometryUtils.smoothPath(
        points,
        iterations: widget.smoothingIterations,
        closed: widget.closeAsPolygon,
      );
    }

    // Push to drawing state and finish directly (not via controller
    // to avoid its onDrawingComplete competing with the overlay's callback)
    final state = controller.drawingState;
    for (final p in points) {
      state.addDrawingPoint(p);
    }
    // For open polylines, temporarily switch mode so finishDrawing
    // creates a DrawablePolyline (needs ≥2 pts) instead of
    // DrawablePolygon (needs ≥3 pts).
    final savedMode = state.activeMode;
    if (!widget.closeAsPolygon) {
      state.setModeQuiet(DrawingMode.polyline);
    }
    state.finishDrawing();
    if (!widget.closeAsPolygon) {
      state.setModeQuiet(savedMode);
    }
    widget.onDrawingComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final previewStyle = widget.previewStyle ??
        widget.controller.drawingState.defaultStyle.copyWith(
          borderWidth: 4.0,
        );

    return SizedBox.expand(
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        // Translucent: let multi-touch events pass through to the map
        // for pinch-zoom/pan while overlay captures single-finger drawing
        behavior: HitTestBehavior.translucent,
        child: CustomPaint(
          painter: _FreehandPainter(
            // Pass a snapshot copy — the old delegate holds the previous
            // snapshot so shouldRepaint can detect changes.
            points: List.of(_screenPoints),
            style: previewStyle,
            closeAsPolygon: widget.closeAsPolygon,
            isDrawing: _isDrawing,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Paints the freehand preview stroke from screen coordinates.
class _FreehandPainter extends CustomPainter {
  final List<Offset> points;
  final ShapeStyle style;
  final bool closeAsPolygon;
  final bool isDrawing;

  _FreehandPainter({
    required this.points,
    required this.style,
    this.closeAsPolygon = true,
    this.isDrawing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final resolved = style.resolve();

    // Draw filled preview area
    if (closeAsPolygon && points.length >= 3) {
      final fillPaint = ui.Paint()
        ..color = resolved.effectiveFillColor
        ..style = ui.PaintingStyle.fill;

      final fillPath = ui.Path()
        ..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw stroke path
    final paint = ui.Paint()
      ..color = resolved.borderColor
      ..strokeWidth = resolved.borderWidth
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    // Draw closing line from last point to first (dashed hint)
    if (closeAsPolygon && points.length >= 3 && isDrawing) {
      final closePaint = ui.Paint()
        ..color = resolved.borderColor.withValues(alpha: 0.4)
        ..strokeWidth = resolved.borderWidth * 0.7
        ..style = ui.PaintingStyle.stroke
        ..strokeCap = ui.StrokeCap.round;

      canvas.drawLine(points.last, points.first, closePaint);
    }
  }

  @override
  bool shouldRepaint(_FreehandPainter oldDelegate) =>
      points.length != oldDelegate.points.length ||
      isDrawing != oldDelegate.isDrawing;
}
