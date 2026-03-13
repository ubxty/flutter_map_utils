/// The mode the drawing/editing system is currently in.
enum DrawingMode {
  /// No active tool. Map behaves normally.
  none,

  /// Drawing a polygon by tapping vertices.
  polygon,

  /// Drawing a polyline by tapping points.
  polyline,

  /// Drawing a rectangle by tapping two corners.
  rectangle,

  /// Drawing a circle by tapping center then dragging radius.
  circle,

  /// Freehand drawing by dragging on the map.
  freehand,

  /// Selection mode — tap shapes to select them.
  select,

  /// Measurement mode — tap points to measure distances.
  measure,

  /// Drawing a hole inside an existing polygon.
  hole,
}
