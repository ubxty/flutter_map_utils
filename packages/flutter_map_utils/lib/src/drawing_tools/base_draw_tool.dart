import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// Callback signature for when a drawing operation completes.
typedef DrawingCompleteCallback = void Function();

/// Base class for all drawing tools.
///
/// Provides the shared lifecycle (addPoint → preview → finish/cancel) and
/// wires into [DrawingState] for state management. Each concrete tool
/// overrides [buildPreviewLayers] to render its own live preview.
abstract class BaseDrawTool extends StatefulWidget {
  /// The drawing state this tool reads from and writes to.
  final DrawingState drawingState;

  /// Called when the drawing is finalized (shape committed).
  final DrawingCompleteCallback? onDrawingComplete;

  /// Whether to show edge length labels while drawing.
  final bool showEdgeLengths;

  /// Whether to show live area preview while drawing polygons.
  final bool showAreaPreview;

  /// Auto-close screen distance in logical pixels. When the last tap is
  /// within this distance of the first vertex, auto-close is triggered.
  /// Set to 0 to disable.
  final double autoCloseThreshold;

  const BaseDrawTool({
    super.key,
    required this.drawingState,
    this.onDrawingComplete,
    this.showEdgeLengths = true,
    this.showAreaPreview = true,
    this.autoCloseThreshold = 15.0,
  });
}

/// Shared state for drawing tools.
///
/// Subclasses override [handleTap] and [buildPreviewLayers].
abstract class BaseDrawToolState<T extends BaseDrawTool> extends State<T> {
  /// Haversine distance calculator.
  static const Distance _haversine = Distance();

  /// Formats a distance value to a human-readable string.
  String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(1)} m';
  }

  /// Formats an area value to a human-readable string.
  String formatArea(double sqMeters) {
    if (sqMeters >= 1e6) {
      return '${(sqMeters / 1e6).toStringAsFixed(3)} km²';
    }
    if (sqMeters >= 1e4) {
      return '${(sqMeters / 1e4).toStringAsFixed(2)} ha';
    }
    return '${sqMeters.toStringAsFixed(1)} m²';
  }

  /// Handle a map tap. Called by [build] when user taps the map.
  void handleTap(LatLng point);

  /// Handle a map secondary tap (right-click / two-finger tap).
  /// Default: finishes the drawing.
  void handleSecondaryTap(LatLng point) => finishDrawing();

  /// Handle a map long press. Default: finishes the drawing.
  void handleLongPress(LatLng point) => finishDrawing();

  /// Build the preview layers shown while drawing.
  List<Widget> buildPreviewLayers(BuildContext context, MapCamera camera);

  /// Finish the drawing and commit the shape.
  void finishDrawing();

  /// Cancel the drawing and discard points.
  void cancelDrawing() {
    widget.drawingState.cancelDrawing();
  }

  /// Undo the last drawing point.
  void undoPoint() {
    widget.drawingState.undoDrawingPoint();
  }

  /// Check if [point] is close enough to [target] on screen to trigger
  /// auto-close.
  bool isNearFirstVertex(
    MapCamera camera,
    LatLng point,
    LatLng target,
  ) {
    if (widget.autoCloseThreshold <= 0) return false;
    final screenPoint = camera.latLngToScreenOffset(point);
    final screenTarget = camera.latLngToScreenOffset(target);
    final dx = screenPoint.dx - screenTarget.dx;
    final dy = screenPoint.dy - screenTarget.dy;
    return (dx * dx + dy * dy) <=
        widget.autoCloseThreshold * widget.autoCloseThreshold;
  }

  /// Build edge length label markers for the current drawing points.
  List<Marker> buildEdgeLengthMarkers(List<LatLng> points) {
    if (!widget.showEdgeLengths || points.length < 2) return const [];

    final markers = <Marker>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final midLat = (a.latitude + b.latitude) / 2;
      final midLng = (a.longitude + b.longitude) / 2;
      final dist = _haversine.distance(a, b);

      markers.add(Marker(
        point: LatLng(midLat, midLng),
        width: 80,
        height: 24,
        child: _EdgeLengthLabel(text: formatDistance(dist)),
      ));
    }
    return markers;
  }

  /// Build an area preview marker at the centroid.
  Marker? buildAreaPreviewMarker(List<LatLng> points) {
    if (!widget.showAreaPreview || points.length < 3) return null;

    // Simple centroid (average of points)
    var latSum = 0.0;
    var lngSum = 0.0;
    for (final p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    final centroid =
        LatLng(latSum / points.length, lngSum / points.length);

    // Shoelace formula (planar approximation — fine for small areas)
    final area = _computeSphericalArea(points);

    return Marker(
      point: centroid,
      width: 120,
      height: 28,
      child: _AreaPreviewLabel(text: formatArea(area)),
    );
  }

  /// Compute geodesic polygon area using the spherical excess method.
  double _computeSphericalArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    const earthRadius = 6371000.0; // meters
    final n = points.length;
    var sum = 0.0;

    for (var i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      final lat1 = p1.latitudeInRad;
      final lat2 = p2.latitudeInRad;
      final dLng = p2.longitudeInRad - p1.longitudeInRad;
      sum += dLng * (2 + _sin(lat1) + _sin(lat2));
    }

    return (sum.abs() * earthRadius * earthRadius / 2);
  }

  static double _sin(double x) {
    // Use dart:math sin via LatLng's radian conversion
    return _sinImpl(x);
  }

  static double _sinImpl(double x) {
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final layers = buildPreviewLayers(context, camera);

    if (layers.isEmpty) return const SizedBox.shrink();

    return Stack(children: layers);
  }
}

/// Small label widget showing distance along an edge.
class _EdgeLengthLabel extends StatelessWidget {
  final String text;
  const _EdgeLengthLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xDD000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Small label widget showing area preview.
class _AreaPreviewLabel extends StatelessWidget {
  final String text;
  const _AreaPreviewLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xDD1565C0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
