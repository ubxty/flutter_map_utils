import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'package:google_map_utils/src/drawing/gm_drawing_controller.dart';

/// Data for a single polygon or open polyline rendered by [GmPolygonOverlay].
class GmOverlayPolygon {
  final List<LatLng> points;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  /// When true, the path is closed into a filled polygon.
  /// When false, the path is drawn as an open polyline.
  final bool closed;

  /// When true, each vertex is drawn as a small filled circle dot.
  final bool showVertexDots;

  /// Radius of vertex dots in logical pixels (only when [showVertexDots] is true).
  final double vertexDotRadius;

  const GmOverlayPolygon({
    required this.points,
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 4.0,
    this.closed = true,
    this.showVertexDots = false,
    this.vertexDotRadius = 5.0,
  });
}

/// A Flutter-level overlay that renders polygons and polylines on top of the
/// underlying Google Maps canvas — including above [TileOverlay] layers such
/// as NAIP satellite imagery.
///
/// Place this in a [Stack] above the [GoogleMap] widget:
///
/// ```dart
/// Stack(
///   children: [
///     GoogleMap(...),                    // base map + NAIP TileOverlay
///     GmPolygonOverlay(                  // rendered ABOVE map canvas
///       controller: _drawingController,
///       polygons: myPolygonList,
///     ),
///     GmFreehandOverlay(...),
///     GmVertexOverlay(...),
///   ],
/// )
/// ```
///
/// Positions are refreshed automatically on camera move (via controller
/// listener) and whenever [polygons] changes in [didUpdateWidget].
class GmPolygonOverlay extends StatefulWidget {
  final GmDrawingController controller;
  final List<GmOverlayPolygon> polygons;

  const GmPolygonOverlay({
    super.key,
    required this.controller,
    this.polygons = const [],
  });

  @override
  State<GmPolygonOverlay> createState() => _GmPolygonOverlayState();
}

class _GmPolygonOverlayState extends State<GmPolygonOverlay> {
  /// Cached screen-coordinate lists parallel to [widget.polygons].
  List<List<Offset>> _screenPolygons = [];
  bool _refreshing = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshPositions();
    });
  }

  @override
  void didUpdateWidget(GmPolygonOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    // Refresh when the polygon data changes (point added/removed, polygon added).
    if (_polygonsChanged(oldWidget.polygons, widget.polygons)) {
      _refreshPositions();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // Camera moved — debounce to avoid excessive refreshes during pan/zoom.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), _refreshPositions);
  }

  /// Returns true when polygon data has changed enough to warrant a refresh.
  bool _polygonsChanged(List<GmOverlayPolygon> a, List<GmOverlayPolygon> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].points.length != b[i].points.length) return true;
    }
    return false;
  }

  Future<void> _refreshPositions() async {
    if (_refreshing || !mounted) return;
    if (widget.controller.mapController == null) return;
    _refreshing = true;

    final newPolygons = <List<Offset>>[];
    for (final poly in widget.polygons) {
      final screenPts = <Offset>[];
      for (final pt in poly.points) {
        final screen = await widget.controller.latLngToScreen(pt);
        if (screen != null) screenPts.add(screen);
      }
      newPolygons.add(screenPts);
    }

    _screenPolygons = newPolygons;
    _refreshing = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_screenPolygons.isEmpty) return const SizedBox.shrink();

    return SizedBox.expand(
      child: CustomPaint(
        painter: _PolygonOverlayPainter(
          screenPolygons: _screenPolygons,
          polygons: widget.polygons,
        ),
      ),
    );
  }
}

class _PolygonOverlayPainter extends CustomPainter {
  final List<List<Offset>> screenPolygons;
  final List<GmOverlayPolygon> polygons;

  const _PolygonOverlayPainter({
    required this.screenPolygons,
    required this.polygons,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final n = screenPolygons.length < polygons.length
        ? screenPolygons.length
        : polygons.length;

    for (var i = 0; i < n; i++) {
      final screens = screenPolygons[i];
      final data = polygons[i];

      if (data.closed && screens.length < 3) continue;
      if (!data.closed && screens.length < 2) continue;

      final path = ui.Path()..moveTo(screens[0].dx, screens[0].dy);
      for (final pt in screens.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      if (data.closed) path.close();

      // Fill (polygons only)
      if (data.closed) {
        canvas.drawPath(
          path,
          ui.Paint()
            ..color = data.fillColor
            ..style = ui.PaintingStyle.fill,
        );
      }

      // Stroke
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = data.strokeColor
          ..strokeWidth = data.strokeWidth
          ..style = ui.PaintingStyle.stroke
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeCap = ui.StrokeCap.round,
      );

      // Vertex dots
      if (data.showVertexDots) {
        final dotPaint = ui.Paint()
          ..color = data.strokeColor
          ..style = ui.PaintingStyle.fill;
        for (final pt in screens) {
          canvas.drawCircle(pt, data.vertexDotRadius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PolygonOverlayPainter old) =>
      old.screenPolygons != screenPolygons;
}
