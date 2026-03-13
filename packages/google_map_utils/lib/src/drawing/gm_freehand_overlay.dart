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
  final int smoothingIterations;

  /// Called when drawing finishes (shape committed).
  final VoidCallback? onDrawingComplete;

  const GmFreehandOverlay({
    super.key,
    required this.controller,
    this.previewStyle,
    this.closeAsPolygon = true,
    this.simplificationTolerance = 5.0,
    this.minPoints = 4,
    this.smoothingIterations = 2,
    this.onDrawingComplete,
  });

  @override
  State<GmFreehandOverlay> createState() => _GmFreehandOverlayState();
}

class _GmFreehandOverlayState extends State<GmFreehandOverlay> {
  bool _isDrawing = false;
  final List<Offset> _screenPoints = [];

  void _handlePointerDown(PointerDownEvent event) {
    _isDrawing = true;
    _screenPoints.clear();
    _screenPoints.add(event.localPosition);
    widget.controller.drawingState.beginShapeDrag();
    setState(() {});
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDrawing) return;
    _screenPoints.add(event.localPosition);
    setState(() {});
  }

  Future<void> _handlePointerUp(PointerUpEvent event) async {
    if (!_isDrawing) return;
    _isDrawing = false;
    widget.controller.drawingState.endShapeDrag();

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

    // Simplify
    var points = GeometryUtils.simplifyPath(
      latLngPoints,
      tolerance: widget.simplificationTolerance,
    );
    if (points.length < widget.minPoints) {
      points = List.of(latLngPoints);
    }

    // Smooth
    if (widget.smoothingIterations > 0 && points.length >= 3) {
      points = GeometryUtils.smoothPath(
        points,
        iterations: widget.smoothingIterations,
        closed: widget.closeAsPolygon,
      );
    }

    // Push to drawing state and finish
    for (final p in points) {
      controller.drawingState.addDrawingPoint(p);
    }
    controller.finishDrawing();
    widget.onDrawingComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _FreehandPainter(
          points: _screenPoints,
          style: widget.previewStyle ??
              widget.controller.drawingState.defaultStyle,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Paints the freehand preview stroke from screen coordinates.
class _FreehandPainter extends CustomPainter {
  final List<Offset> points;
  final ShapeStyle style;

  _FreehandPainter({required this.points, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final resolved = style.resolve();
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
  }

  @override
  bool shouldRepaint(_FreehandPainter oldDelegate) =>
      points.length != oldDelegate.points.length;
}
