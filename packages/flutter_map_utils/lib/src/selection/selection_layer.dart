import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// Handles tap-based selection of shapes.
///
/// When the mode is [DrawingMode.select], taps are evaluated against
/// all committed shapes using hit testing. The closest shape under the
/// tap point is selected via [DrawingState.selectShape].
class SelectionLayer extends StatelessWidget {
  final DrawingState drawingState;

  /// Tap tolerance in meters — shapes within this distance of a tap
  /// point are considered hits for polylines/circles.
  final double tapToleranceMeters;

  const SelectionLayer({
    super.key,
    required this.drawingState,
    this.tapToleranceMeters = 20.0,
  });

  /// Evaluate a tap and select the matching shape, if any.
  ///
  /// Call this from your [MapOptions.onTap] callback when in select mode.
  void handleTap(LatLng point) {
    final shapes = drawingState.shapes;
    if (shapes.isEmpty) {
      drawingState.clearSelection();
      return;
    }

    String? hitId;
    double hitDist = double.infinity;

    for (final shape in shapes) {
      final dist = _distanceToShape(point, shape);
      if (dist != null && dist < hitDist) {
        hitDist = dist;
        hitId = shape.id;
      }
    }

    if (hitId != null && hitDist <= tapToleranceMeters) {
      drawingState.selectShape(hitId);
    } else {
      drawingState.clearSelection();
    }
  }

  /// Compute the distance from a point to a shape.
  /// For polygons/rectangles, returns 0 if inside, or edge distance if outside.
  /// For polylines, returns nearest edge distance.
  /// For circles, returns distance from boundary.
  double? _distanceToShape(LatLng point, DrawableShape shape) {
    const haversine = Distance();

    switch (shape) {
      case final DrawablePolygon s:
        if (GeometryUtils.pointInPolygon(point, s.points)) return 0;
        return _nearestEdgeDistance(point, s.points, closed: true);
      case final DrawableRectangle s:
        if (GeometryUtils.pointInPolygon(point, s.points)) return 0;
        return _nearestEdgeDistance(point, s.points, closed: true);
      case final DrawablePolyline s:
        return _nearestEdgeDistance(point, s.points, closed: false);
      case final DrawableCircle s:
        final distToCenter = haversine.distance(point, s.center);
        return (distToCenter - s.radiusMeters).abs();
    }
  }

  double? _nearestEdgeDistance(
    LatLng cursor,
    List<LatLng> points, {
    required bool closed,
  }) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      return const Distance().distance(cursor, points.first);
    }

    double best = double.infinity;
    final edgeCount = closed ? points.length : points.length - 1;

    for (var i = 0; i < edgeCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final (:point, t: _) =
          GeometryUtils.nearestPointOnSegment(cursor, a, b);
      final dist = const Distance().distance(cursor, point);
      if (dist < best) best = dist;
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    // This layer is invisible — selection is driven by handleTap()
    return const SizedBox.shrink();
  }
}
