import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:map_utils_core/map_utils_core.dart';

import 'package:google_map_utils/src/gm_extensions.dart';

/// Converts [DrawableShape] objects to Google Maps native shape sets.
///
/// Call [buildAll] to get the complete polygon, polyline, circle, and marker
/// sets ready to pass to [gm.GoogleMap]:
///
/// ```dart
/// final renderer = GmShapeRenderer(drawingState: state);
/// GoogleMap(
///   polygons: renderer.polygons,
///   polylines: renderer.polylines,
///   circles: renderer.circles,
/// )
/// ```
class GmShapeRenderer {
  final DrawingState drawingState;

  /// Style override for the selected shape.
  final ShapeStyle? selectedStyle;

  /// Callback when a shape polygon is tapped.
  final void Function(String shapeId)? onShapeTap;

  GmShapeRenderer({
    required this.drawingState,
    this.selectedStyle,
    this.onShapeTap,
  });

  /// Build Google Maps polygons from all polygon + rectangle shapes.
  Set<gm.Polygon> get polygons {
    final result = <gm.Polygon>{};
    final selectedId = drawingState.selectedShapeId;

    for (final shape in drawingState.shapes) {
      final isSelected = shape.id == selectedId;
      final style = isSelected
          ? (selectedStyle ?? shape.style.resolve(selected: true))
          : shape.style.resolve();

      switch (shape) {
        case final DrawablePolygon s:
          result.add(gm.Polygon(
            polygonId: gm.PolygonId(s.id),
            points: s.points.toGm(),
            holes: s.holes.map((h) => h.toGm()).toList(),
            fillColor: style.effectiveFillColor,
            strokeColor: style.borderColor,
            strokeWidth: style.borderWidth.round(),
            consumeTapEvents: onShapeTap != null,
            onTap: onShapeTap != null ? () => onShapeTap!(s.id) : null,
          ));
        case final DrawableRectangle s:
          result.add(gm.Polygon(
            polygonId: gm.PolygonId(s.id),
            points: s.points.toGm(),
            fillColor: style.effectiveFillColor,
            strokeColor: style.borderColor,
            strokeWidth: style.borderWidth.round(),
            consumeTapEvents: onShapeTap != null,
            onTap: onShapeTap != null ? () => onShapeTap!(s.id) : null,
          ));
        default:
          break;
      }
    }
    return result;
  }

  /// Build Google Maps polylines from all polyline shapes.
  Set<gm.Polyline> get polylines {
    final result = <gm.Polyline>{};
    final selectedId = drawingState.selectedShapeId;

    for (final shape in drawingState.shapes) {
      if (shape is! DrawablePolyline) continue;
      final isSelected = shape.id == selectedId;
      final style = isSelected
          ? (selectedStyle ?? shape.style.resolve(selected: true))
          : shape.style.resolve();

      result.add(gm.Polyline(
        polylineId: gm.PolylineId(shape.id),
        points: shape.points.toGm(),
        color: style.borderColor,
        width: style.borderWidth.round(),
        patterns: style.strokeType.toGmPattern(),
        consumeTapEvents: onShapeTap != null,
        onTap: onShapeTap != null ? () => onShapeTap!(shape.id) : null,
      ));
    }
    return result;
  }

  /// Build Google Maps circles from all circle shapes.
  Set<gm.Circle> get circles {
    final result = <gm.Circle>{};
    final selectedId = drawingState.selectedShapeId;

    for (final shape in drawingState.shapes) {
      if (shape is! DrawableCircle) continue;
      final isSelected = shape.id == selectedId;
      final style = isSelected
          ? (selectedStyle ?? shape.style.resolve(selected: true))
          : shape.style.resolve();

      result.add(gm.Circle(
        circleId: gm.CircleId(shape.id),
        center: shape.center.toGm(),
        radius: shape.radiusMeters,
        fillColor: style.effectiveFillColor,
        strokeColor: style.borderColor,
        strokeWidth: style.borderWidth.round(),
        consumeTapEvents: onShapeTap != null,
        onTap: onShapeTap != null ? () => onShapeTap!(shape.id) : null,
      ));
    }
    return result;
  }

  /// Build a preview polyline for points currently being drawn.
  Set<gm.Polyline> buildDrawingPreview({
    ShapeStyle? previewStyle,
    bool closed = false,
  }) {
    final points = drawingState.drawingPoints;
    if (points.length < 2) return {};

    final style =
        (previewStyle ?? drawingState.defaultStyle).resolve();
    final gmPoints = points.toGm();

    // Close the preview if it's a polygon-like mode
    if (closed && gmPoints.length >= 3) {
      gmPoints.add(gmPoints.first);
    }

    return {
      gm.Polyline(
        polylineId: const gm.PolylineId('__drawing_preview__'),
        points: gmPoints,
        color: style.borderColor,
        width: style.borderWidth.round(),
        patterns: style.strokeType.toGmPattern(),
      ),
    };
  }

  /// Build a preview circle during circle drawing.
  Set<gm.Circle> buildCirclePreview({
    double? radiusMeters,
    ShapeStyle? previewStyle,
  }) {
    final center = drawingState.circleCenter;
    if (center == null || radiusMeters == null || radiusMeters <= 0) return {};

    final style =
        (previewStyle ?? drawingState.defaultStyle).resolve();

    return {
      gm.Circle(
        circleId: const gm.CircleId('__circle_preview__'),
        center: center.toGm(),
        radius: radiusMeters,
        fillColor: style.effectiveFillColor,
        strokeColor: style.borderColor,
        strokeWidth: style.borderWidth.round(),
      ),
    };
  }
}
