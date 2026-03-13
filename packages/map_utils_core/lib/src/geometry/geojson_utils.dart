import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'package:map_utils_core/src/core/shape_model.dart';
import 'package:map_utils_core/src/core/shape_style.dart';

const _uuid = Uuid();

/// GeoJSON import/export utilities.
///
/// Supports Point, LineString, Polygon, MultiPolygon, Feature, and
/// FeatureCollection geometries.
abstract final class GeoJsonUtils {
  // -- Export --

  /// Convert a single shape to a GeoJSON Feature map.
  static Map<String, dynamic> toGeoJsonFeature(DrawableShape shape) {
    final properties = <String, dynamic>{
      'shapeType': shape.type.name,
      'style': shape.style.toJson(),
      ...shape.metadata,
    };

    // Store circle radius in properties
    if (shape is DrawableCircle) {
      properties['radius'] = shape.radiusMeters;
    }

    return {
      'type': 'Feature',
      'id': shape.id,
      'properties': properties,
      'geometry': _shapeToGeometry(shape),
    };
  }

  /// Convert a list of shapes to a GeoJSON FeatureCollection map.
  static Map<String, dynamic> toFeatureCollection(
      List<DrawableShape> shapes) {
    return {
      'type': 'FeatureCollection',
      'features': shapes.map(toGeoJsonFeature).toList(),
    };
  }

  /// Convert shapes to a GeoJSON string.
  static String toGeoJsonString(
    List<DrawableShape> shapes, {
    bool pretty = false,
  }) {
    final map = toFeatureCollection(shapes);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  // -- Import --

  /// Parse a GeoJSON string into shapes.
  static List<DrawableShape> fromGeoJsonString(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return fromGeoJson(map);
  }

  /// Parse a GeoJSON map into shapes.
  static List<DrawableShape> fromGeoJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'FeatureCollection':
        final features = json['features'] as List<dynamic>;
        return features
            .map((f) => _featureToShape(f as Map<String, dynamic>))
            .whereType<DrawableShape>()
            .toList();
      case 'Feature':
        final shape = _featureToShape(json);
        return shape != null ? [shape] : [];
      default:
        // Try as raw geometry
        final shape = _geometryToShape(json);
        return shape != null ? [shape] : [];
    }
  }

  // -- Internal export --

  static Map<String, dynamic> _shapeToGeometry(DrawableShape shape) {
    return switch (shape) {
      final DrawablePolygon s => _polygonGeometry(s),
      final DrawablePolyline s => {
          'type': 'LineString',
          'coordinates':
              s.points.map((p) => [p.longitude, p.latitude]).toList(),
        },
      final DrawableCircle s => {
          'type': 'Point',
          'coordinates': [s.center.longitude, s.center.latitude],
        },
      final DrawableRectangle s => {
          'type': 'Polygon',
          'coordinates': [
            [
              ...s.points.map((p) => [p.longitude, p.latitude]),
              [s.points.first.longitude, s.points.first.latitude],
            ],
          ],
        },
    };
  }

  static Map<String, dynamic> _polygonGeometry(DrawablePolygon s) {
    final rings = <List<List<double>>>[];
    // Outer ring (closed)
    rings.add([
      ...s.points.map((p) => [p.longitude, p.latitude]),
      [s.points.first.longitude, s.points.first.latitude],
    ]);
    // Holes
    for (final hole in s.holes) {
      rings.add([
        ...hole.map((p) => [p.longitude, p.latitude]),
        [hole.first.longitude, hole.first.latitude],
      ]);
    }
    return {
      'type': 'Polygon',
      'coordinates': rings,
    };
  }

  // -- Internal import --

  static DrawableShape? _featureToShape(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return null;

    final rawProps = feature['properties'];
    final properties = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : <String, dynamic>{};
    final id = (feature['id'] as String?) ?? _uuid.v4();

    // Extract style if present
    final rawStyle = properties['style'];
    final styleJson =
        rawStyle is Map ? Map<String, dynamic>.from(rawStyle) : null;
    final style = styleJson != null
        ? ShapeStyle.fromJson(styleJson)
        : const ShapeStyle();

    // Extract metadata (everything except our internal keys)
    final metadata = Map<String, dynamic>.from(properties)
      ..remove('shapeType')
      ..remove('style');

    // Check if shapeType hints at circle, or Point with radius property
    final shapeType = properties['shapeType'] as String?;
    if (geometry['type'] == 'Point' &&
        (shapeType == 'circle' || properties.containsKey('radius'))) {
      return _parseCircle(geometry, id, style, metadata, properties);
    }

    return _geometryToShape(
      geometry,
      id: id,
      style: style,
      metadata: metadata,
      shapeType: shapeType,
    );
  }

  static DrawableShape? _geometryToShape(
    Map<String, dynamic> geometry, {
    String? id,
    ShapeStyle style = const ShapeStyle(),
    Map<String, dynamic> metadata = const {},
    String? shapeType,
  }) {
    final type = geometry['type'] as String?;
    final effectiveId = id ?? _uuid.v4();

    switch (type) {
      case 'Point':
        final coords = geometry['coordinates'] as List<dynamic>;
        return DrawableCircle(
          id: effectiveId,
          center: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
          radiusMeters: 0,
          style: style,
          metadata: metadata,
        );

      case 'LineString':
        final coords = geometry['coordinates'] as List<dynamic>;
        final points = _parseCoordList(coords);
        if (points.length < 2) return null;
        return DrawablePolyline(
          id: effectiveId,
          points: points,
          style: style,
          metadata: metadata,
        );

      case 'Polygon':
        final rings = geometry['coordinates'] as List<dynamic>;
        if (rings.isEmpty) return null;
        final outerRing = _parseCoordList(rings[0] as List<dynamic>);
        final points = _removeClosingPoint(outerRing);
        if (points.length < 3) return null;

        final holes = <List<LatLng>>[];
        for (var i = 1; i < rings.length; i++) {
          final hole = _parseCoordList(rings[i] as List<dynamic>);
          holes.add(_removeClosingPoint(hole));
        }

        if (shapeType == 'rectangle' &&
            points.length == 4 &&
            holes.isEmpty) {
          return DrawableRectangle(
            id: effectiveId,
            points: points,
            style: style,
            metadata: metadata,
          );
        }

        return DrawablePolygon(
          id: effectiveId,
          points: points,
          holes: holes,
          style: style,
          metadata: metadata,
        );

      case 'MultiPolygon':
        final polygons = geometry['coordinates'] as List<dynamic>;
        if (polygons.isEmpty) return null;
        final firstPolygon = polygons[0] as List<dynamic>;
        return _geometryToShape(
          {'type': 'Polygon', 'coordinates': firstPolygon},
          id: effectiveId,
          style: style,
          metadata: metadata,
        );

      default:
        return null;
    }
  }

  static DrawableCircle? _parseCircle(
    Map<String, dynamic> geometry,
    String id,
    ShapeStyle style,
    Map<String, dynamic> metadata,
    Map<String, dynamic> properties,
  ) {
    final coords = geometry['coordinates'] as List<dynamic>;
    final radius = (properties['radius'] as num?)?.toDouble() ?? 0;
    return DrawableCircle(
      id: id,
      center: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
      radiusMeters: radius,
      style: style,
      metadata: metadata,
    );
  }

  static List<LatLng> _parseCoordList(List<dynamic> coords) {
    return coords.map((c) {
      final pair = c as List<dynamic>;
      return LatLng(
        (pair[1] as num).toDouble(),
        (pair[0] as num).toDouble(),
      );
    }).toList();
  }

  static List<LatLng> _removeClosingPoint(List<LatLng> points) {
    if (points.length > 1 &&
        points.first.latitude == points.last.latitude &&
        points.first.longitude == points.last.longitude) {
      return points.sublist(0, points.length - 1);
    }
    return points;
  }
}
