import 'package:latlong2/latlong.dart';

import 'package:map_utils_core/src/core/shape_style.dart';

/// The type of a drawable shape.
enum ShapeType { polygon, polyline, circle, rectangle }

/// Base class for all drawable shapes managed by [DrawingState].
///
/// Each shape has a unique [id], a [style], optional [metadata],
/// and serialization support via [toJson]/[fromJson].
sealed class DrawableShape {
  /// Unique identifier (UUID).
  final String id;

  /// Visual style.
  final ShapeStyle style;

  /// Arbitrary user metadata (tags, names, etc.).
  final Map<String, dynamic> metadata;

  /// The type discriminator for serialization.
  ShapeType get type;

  /// All points that define this shape's geometry.
  List<LatLng> get allPoints;

  const DrawableShape({
    required this.id,
    this.style = const ShapeStyle(),
    this.metadata = const {},
  });

  DrawableShape copyWith({
    String? id,
    ShapeStyle? style,
    Map<String, dynamic>? metadata,
  });

  Map<String, dynamic> toJson();

  static DrawableShape fromJson(Map<String, dynamic> json) {
    final type = ShapeType.values.byName(json['type'] as String);
    return switch (type) {
      ShapeType.polygon => DrawablePolygon.fromJson(json),
      ShapeType.polyline => DrawablePolyline.fromJson(json),
      ShapeType.circle => DrawableCircle.fromJson(json),
      ShapeType.rectangle => DrawableRectangle.fromJson(json),
    };
  }
}

class DrawablePolygon extends DrawableShape {
  final List<LatLng> points;
  final List<List<LatLng>> holes;

  @override
  ShapeType get type => ShapeType.polygon;

  @override
  List<LatLng> get allPoints => points;

  const DrawablePolygon({
    required super.id,
    required this.points,
    this.holes = const [],
    super.style,
    super.metadata,
  });

  @override
  DrawablePolygon copyWith({
    String? id,
    List<LatLng>? points,
    List<List<LatLng>>? holes,
    ShapeStyle? style,
    Map<String, dynamic>? metadata,
  }) {
    return DrawablePolygon(
      id: id ?? this.id,
      points: points ?? this.points,
      holes: holes ?? this.holes,
      style: style ?? this.style,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'points': points.map(_latLngToJson).toList(),
        'holes': holes
            .map((h) => h.map(_latLngToJson).toList())
            .toList(),
        'style': style.toJson(),
        'metadata': metadata,
      };

  factory DrawablePolygon.fromJson(Map<String, dynamic> json) {
    return DrawablePolygon(
      id: json['id'] as String,
      points: (json['points'] as List).map(_latLngFromJson).toList(),
      holes: (json['holes'] as List?)
              ?.map(
                  (h) => (h as List).map(_latLngFromJson).toList())
              .toList() ??
          [],
      style: json['style'] != null
          ? ShapeStyle.fromJson(json['style'] as Map<String, dynamic>)
          : const ShapeStyle(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class DrawablePolyline extends DrawableShape {
  final List<LatLng> points;

  @override
  ShapeType get type => ShapeType.polyline;

  @override
  List<LatLng> get allPoints => points;

  const DrawablePolyline({
    required super.id,
    required this.points,
    super.style,
    super.metadata,
  });

  @override
  DrawablePolyline copyWith({
    String? id,
    List<LatLng>? points,
    ShapeStyle? style,
    Map<String, dynamic>? metadata,
  }) {
    return DrawablePolyline(
      id: id ?? this.id,
      points: points ?? this.points,
      style: style ?? this.style,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'points': points.map(_latLngToJson).toList(),
        'style': style.toJson(),
        'metadata': metadata,
      };

  factory DrawablePolyline.fromJson(Map<String, dynamic> json) {
    return DrawablePolyline(
      id: json['id'] as String,
      points: (json['points'] as List).map(_latLngFromJson).toList(),
      style: json['style'] != null
          ? ShapeStyle.fromJson(json['style'] as Map<String, dynamic>)
          : const ShapeStyle(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class DrawableCircle extends DrawableShape {
  final LatLng center;
  final double radiusMeters;

  @override
  ShapeType get type => ShapeType.circle;

  @override
  List<LatLng> get allPoints => [center];

  const DrawableCircle({
    required super.id,
    required this.center,
    required this.radiusMeters,
    super.style,
    super.metadata,
  });

  @override
  DrawableCircle copyWith({
    String? id,
    LatLng? center,
    double? radiusMeters,
    ShapeStyle? style,
    Map<String, dynamic>? metadata,
  }) {
    return DrawableCircle(
      id: id ?? this.id,
      center: center ?? this.center,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      style: style ?? this.style,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'center': _latLngToJson(center),
        'radiusMeters': radiusMeters,
        'style': style.toJson(),
        'metadata': metadata,
      };

  factory DrawableCircle.fromJson(Map<String, dynamic> json) {
    return DrawableCircle(
      id: json['id'] as String,
      center: _latLngFromJson(json['center']),
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      style: json['style'] != null
          ? ShapeStyle.fromJson(json['style'] as Map<String, dynamic>)
          : const ShapeStyle(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class DrawableRectangle extends DrawableShape {
  final List<LatLng> points; // Always 4 points

  @override
  ShapeType get type => ShapeType.rectangle;

  @override
  List<LatLng> get allPoints => points;

  const DrawableRectangle({
    required super.id,
    required this.points,
    super.style,
    super.metadata,
  }) : assert(points.length == 4, 'Rectangle must have exactly 4 points');

  factory DrawableRectangle.fromCorners({
    required String id,
    required LatLng corner1,
    required LatLng corner2,
    ShapeStyle style = const ShapeStyle(),
    Map<String, dynamic> metadata = const {},
  }) {
    final north = corner1.latitude > corner2.latitude
        ? corner1.latitude
        : corner2.latitude;
    final south = corner1.latitude < corner2.latitude
        ? corner1.latitude
        : corner2.latitude;
    final east = corner1.longitude > corner2.longitude
        ? corner1.longitude
        : corner2.longitude;
    final west = corner1.longitude < corner2.longitude
        ? corner1.longitude
        : corner2.longitude;

    return DrawableRectangle(
      id: id,
      points: [
        LatLng(north, west), // NW
        LatLng(north, east), // NE
        LatLng(south, east), // SE
        LatLng(south, west), // SW
      ],
      style: style,
      metadata: metadata,
    );
  }

  @override
  DrawableRectangle copyWith({
    String? id,
    List<LatLng>? points,
    ShapeStyle? style,
    Map<String, dynamic>? metadata,
  }) {
    return DrawableRectangle(
      id: id ?? this.id,
      points: points ?? this.points,
      style: style ?? this.style,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'points': points.map(_latLngToJson).toList(),
        'style': style.toJson(),
        'metadata': metadata,
      };

  factory DrawableRectangle.fromJson(Map<String, dynamic> json) {
    return DrawableRectangle(
      id: json['id'] as String,
      points: (json['points'] as List).map(_latLngFromJson).toList(),
      style: json['style'] != null
          ? ShapeStyle.fromJson(json['style'] as Map<String, dynamic>)
          : const ShapeStyle(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

// --- Serialization helpers ---
Map<String, double> _latLngToJson(LatLng ll) => {
      'lat': ll.latitude,
      'lng': ll.longitude,
    };

LatLng _latLngFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return LatLng(
    (map['lat'] as num).toDouble(),
    (map['lng'] as num).toDouble(),
  );
}
