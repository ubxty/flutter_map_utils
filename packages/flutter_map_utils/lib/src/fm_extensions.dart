import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// Extension to convert [StrokeType] to flutter_map's [StrokePattern].
extension StrokeTypeToPattern on StrokeType {
  StrokePattern toStrokePattern() => switch (this) {
        StrokeType.solid => const StrokePattern.solid(),
        StrokeType.dashed => StrokePattern.dashed(segments: const [8, 4]),
        StrokeType.dotted => const StrokePattern.dotted(),
      };
}

/// Flutter Map–specific geometry utilities that depend on flutter_map types.
///
/// These were extracted from [GeometryUtils] because they use
/// [LatLngBounds] and [CameraFit], which are flutter_map-specific.
abstract final class FmGeometryUtils {
  /// Compute the bounding box of a list of points.
  static LatLngBounds boundingBox(List<LatLng> points) {
    assert(points.isNotEmpty, 'Cannot compute bounding box of empty list');
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  /// Create a [CameraFit] that fits all provided shapes with optional padding.
  static CameraFit fitBoundsToShapes(
    List<DrawableShape> shapes, {
    EdgeInsets padding = const EdgeInsets.all(50),
  }) {
    final allPoints = <LatLng>[];
    for (final shape in shapes) {
      allPoints.addAll(shape.allPoints);
    }
    return CameraFit.bounds(bounds: boundingBox(allPoints), padding: padding);
  }
}
