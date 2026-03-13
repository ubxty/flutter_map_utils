/// A comprehensive drawing, editing, and measurement toolkit for flutter_map.
///
/// Re-exports all platform-agnostic types from `map_utils_core` plus
/// flutter_map-specific widgets, extensions, and layers.
library;

// Re-export everything from the platform-agnostic core
export 'package:map_utils_core/map_utils_core.dart';

// Flutter Map extensions (StrokeType→StrokePattern, boundingBox, fitBounds)
export 'src/fm_extensions.dart';

// Drawing tools
export 'src/drawing_tools/base_draw_tool.dart';
export 'src/drawing_tools/circle_draw_tool.dart';
export 'src/drawing_tools/freehand_draw_tool.dart';
export 'src/drawing_tools/polygon_draw_tool.dart';
export 'src/drawing_tools/polyline_draw_tool.dart';
export 'src/drawing_tools/rectangle_draw_tool.dart';

// Layers
export 'src/layers/drawing_layer.dart';

// Editing
export 'src/editing/editable_shape_layer.dart';
export 'src/editing/shape_dragger.dart';

// Selection
export 'src/selection/selection_layer.dart';

// Measurement
export 'src/measurement/measurement_tool.dart';

// UI
export 'src/ui/coordinate_display.dart';
export 'src/ui/geometry_editor.dart';
