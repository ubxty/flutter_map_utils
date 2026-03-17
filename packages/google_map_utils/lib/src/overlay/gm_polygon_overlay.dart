import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

  // Anchor state for synchronous camera-follow transform.
  // On the first camera change we snapshot the current screen positions
  // and camera state. Subsequent camera changes compute a transform from
  // the anchor → current state and apply it to the anchored positions.
  // This keeps the overlay in sync with the map at 60fps without waiting
  // for async platform-channel conversions.
  List<List<Offset>>? _anchorScreenPolygons;
  LatLng? _anchorCenter;
  double? _anchorZoom;
  Size _widgetSize = Size.zero;

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
    final newCenter = widget.controller.cameraCenter;
    final newZoom = widget.controller.currentZoom;

    // Apply synchronous transform for instant visual feedback during
    // pan/zoom/rotate so the overlay moves in parallel with the map.
    if (newCenter != null &&
        _screenPolygons.isNotEmpty &&
        _widgetSize != Size.zero) {
      if (_anchorScreenPolygons == null) {
        // First camera-change: snapshot current accurate positions as anchor.
        _anchorScreenPolygons =
            _screenPolygons.map((l) => List.of(l)).toList();
        _anchorCenter = newCenter;
        _anchorZoom = newZoom;
      } else {
        _applyCameraTransform(newCenter, newZoom);
        if (mounted) setState(() {});
      }
    }

    // Debounced full-accuracy refresh (fires after gesture stops).
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _anchorScreenPolygons = null;
      _anchorCenter = null;
      _anchorZoom = null;
      _refreshPositions();
    });
  }

  /// Compute screen-position deltas from [_anchorCenter]/[_anchorZoom] to
  /// the current camera state and apply them to [_anchorScreenPolygons].
  void _applyCameraTransform(LatLng newCenter, double newZoom) {
    if (_anchorScreenPolygons == null ||
        _anchorCenter == null ||
        _anchorZoom == null) return;

    final dLat = newCenter.latitude - _anchorCenter!.latitude;
    final dLng = newCenter.longitude - _anchorCenter!.longitude;

    final cosLat = math.cos(newCenter.latitude * math.pi / 180);
    final mapSize = 256.0 * math.pow(2.0, newZoom);
    final dpr = widget.controller.devicePixelRatio;

    // Pixels per degree in logical pixels.
    final pxPerDegLng = mapSize / 360.0 / dpr;
    final pxPerDegLat = mapSize / (360.0 * cosLat) / dpr;

    // Camera moves right → features shift left, camera moves up → features
    // shift down.
    final dx = -dLng * pxPerDegLng;
    final dy = dLat * pxPerDegLat;

    final zoomScale = math.pow(2.0, newZoom - _anchorZoom!);

    final cx = _widgetSize.width / 2;
    final cy = _widgetSize.height / 2;

    final newPolygons = <List<Offset>>[];
    for (final anchorPoly in _anchorScreenPolygons!) {
      final transformed = <Offset>[];
      for (final p in anchorPoly) {
        // Scale around screen centre, then translate.
        final sx = cx + (p.dx - cx) * zoomScale + dx;
        final sy = cy + (p.dy - cy) * zoomScale + dy;
        transformed.add(Offset(sx, sy));
      }
      newPolygons.add(transformed);
    }
    _screenPolygons = newPolygons;
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

    try {
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
    } catch (_) {
      // Controller may have been disposed during a map switch;
      // clear cached data so the next refresh can try again.
      _screenPolygons = [];
    } finally {
      _refreshing = false;
      // Clear anchor state — we now have accurate positions.
      _anchorScreenPolygons = null;
      _anchorCenter = null;
      _anchorZoom = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_screenPolygons.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _widgetSize = constraints.biggest;
          return SizedBox.expand(
            child: CustomPaint(
              painter: _PolygonOverlayPainter(
                screenPolygons: _screenPolygons,
                polygons: widget.polygons,
              ),
            ),
          );
        },
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

      final canDrawPath = data.closed
          ? screens.length >= 3
          : screens.length >= 2;

      if (canDrawPath) {
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
      }

      // Vertex dots — always draw when enabled, even for a single point
      if (data.showVertexDots && screens.isNotEmpty) {
        final dotFill = ui.Paint()
          ..color = Colors.yellow
          ..style = ui.PaintingStyle.fill;
        final dotStroke = ui.Paint()
          ..color = data.strokeColor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.0;
        for (final pt in screens) {
          canvas.drawCircle(pt, data.vertexDotRadius, dotFill);
          canvas.drawCircle(pt, data.vertexDotRadius, dotStroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PolygonOverlayPainter old) =>
      old.screenPolygons != screenPolygons;
}
