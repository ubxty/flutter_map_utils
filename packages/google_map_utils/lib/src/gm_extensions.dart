import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:map_utils_core/map_utils_core.dart';
import 'package:latlong2/latlong.dart';

/// Extension to convert [StrokeType] to Google Maps pattern list.
extension StrokeTypeToGmPattern on StrokeType {
  List<gm.PatternItem> toGmPattern() => switch (this) {
        StrokeType.solid => const [],
        StrokeType.dashed => [gm.PatternItem.dash(16), gm.PatternItem.gap(8)],
        StrokeType.dotted => [gm.PatternItem.dot, gm.PatternItem.gap(8)],
      };
}

/// Coordinate conversion between latlong2 [LatLng] and Google Maps [gm.LatLng].
extension LatLngToGm on LatLng {
  gm.LatLng toGm() => gm.LatLng(latitude, longitude);
}

/// Coordinate conversion from Google Maps [gm.LatLng] to latlong2 [LatLng].
extension GmLatLngToCore on gm.LatLng {
  LatLng toCore() => LatLng(latitude, longitude);
}

/// Convert a list of core points to Google Maps points.
extension LatLngListToGm on List<LatLng> {
  List<gm.LatLng> toGm() => map((p) => p.toGm()).toList();
}

/// Google Maps–specific geometry utilities.
abstract final class GmGeometryUtils {
  /// Compute Google Maps [gm.LatLngBounds] from a list of core [LatLng] points.
  static gm.LatLngBounds boundingBox(List<LatLng> points) {
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
    return gm.LatLngBounds(
      southwest: gm.LatLng(minLat, minLng),
      northeast: gm.LatLng(maxLat, maxLng),
    );
  }
}
