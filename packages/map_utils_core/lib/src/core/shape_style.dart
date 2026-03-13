import 'package:flutter/material.dart';

/// Platform-agnostic stroke pattern type.
///
/// Binding packages (flutter_map_utils, google_map_utils) convert this
/// to their native stroke pattern representation.
enum StrokeType {
  /// Continuous solid line.
  solid,

  /// Dashed line (long gaps).
  dashed,

  /// Dotted line (short gaps).
  dotted,
}

/// Visual style configuration for a drawable shape.
///
/// Supports default, selected, and hover states. When rendering, the
/// appropriate state style is applied automatically by the editing layer.
class ShapeStyle {
  /// Fill color of the shape.
  final Color fillColor;

  /// Border/stroke color.
  final Color borderColor;

  /// Border/stroke width in pixels.
  final double borderWidth;

  /// Fill opacity (0.0 to 1.0).
  final double fillOpacity;

  /// Stroke pattern type (solid, dashed, dotted).
  final StrokeType strokeType;

  /// Style applied when the shape is selected.
  final ShapeStyle? selectedOverride;

  /// Style applied when the shape is hovered.
  final ShapeStyle? hoverOverride;

  const ShapeStyle({
    this.fillColor = const Color(0x553388FF),
    this.borderColor = const Color(0xFF3388FF),
    this.borderWidth = 2.0,
    this.fillOpacity = 0.3,
    this.strokeType = StrokeType.solid,
    this.selectedOverride,
    this.hoverOverride,
  });

  /// Effective fill color with opacity applied.
  Color get effectiveFillColor => fillColor.withValues(alpha: fillOpacity);

  /// Create a copy with overridden fields.
  ShapeStyle copyWith({
    Color? fillColor,
    Color? borderColor,
    double? borderWidth,
    double? fillOpacity,
    StrokeType? strokeType,
    ShapeStyle? selectedOverride,
    ShapeStyle? hoverOverride,
  }) {
    return ShapeStyle(
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      strokeType: strokeType ?? this.strokeType,
      selectedOverride: selectedOverride ?? this.selectedOverride,
      hoverOverride: hoverOverride ?? this.hoverOverride,
    );
  }

  /// Resolve the effective style for a given state.
  ShapeStyle resolve({bool selected = false, bool hovered = false}) {
    if (selected && selectedOverride != null) return selectedOverride!;
    if (hovered && hoverOverride != null) return hoverOverride!;
    return this;
  }

  Map<String, dynamic> toJson() => {
        'fillColor': fillColor.toARGB32(),
        'borderColor': borderColor.toARGB32(),
        'borderWidth': borderWidth,
        'fillOpacity': fillOpacity,
        'strokeType': strokeType.name,
      };

  factory ShapeStyle.fromJson(Map<String, dynamic> json) => ShapeStyle(
        fillColor: Color(json['fillColor'] as int),
        borderColor: Color(json['borderColor'] as int),
        borderWidth: (json['borderWidth'] as num).toDouble(),
        fillOpacity: (json['fillOpacity'] as num).toDouble(),
        strokeType: json['strokeType'] != null
            ? StrokeType.values.byName(json['strokeType'] as String)
            : StrokeType.solid,
      );
}

/// Pre-configured style presets for common use cases.
abstract final class ShapeStylePresets {
  /// Blue zone border (default).
  static const zone = ShapeStyle(
    fillColor: Color(0x553388FF),
    borderColor: Color(0xFF3388FF),
    borderWidth: 2.0,
    fillOpacity: 0.3,
  );

  /// Red warning area.
  static const warning = ShapeStyle(
    fillColor: Color(0x55FF4444),
    borderColor: Color(0xFFFF4444),
    borderWidth: 2.5,
    fillOpacity: 0.3,
  );

  /// Green route/path.
  static const route = ShapeStyle(
    fillColor: Color(0x5544BB44),
    borderColor: Color(0xFF44BB44),
    borderWidth: 3.0,
    fillOpacity: 0.2,
  );

  /// Orange selected state.
  static const selected = ShapeStyle(
    fillColor: Color(0x55FF8800),
    borderColor: Color(0xFFFF8800),
    borderWidth: 3.0,
    fillOpacity: 0.4,
  );

  /// Light blue hover state.
  static const hover = ShapeStyle(
    fillColor: Color(0x5566BBFF),
    borderColor: Color(0xFF66BBFF),
    borderWidth: 2.5,
    fillOpacity: 0.35,
  );

  /// Default style with selected/hover states wired up.
  static const defaultWithStates = ShapeStyle(
    fillColor: Color(0x553388FF),
    borderColor: Color(0xFF3388FF),
    borderWidth: 2.0,
    fillOpacity: 0.3,
    selectedOverride: selected,
    hoverOverride: hover,
  );
}
