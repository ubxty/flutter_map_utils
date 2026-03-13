/// Drawing, editing & measurement widgets for Google Maps Flutter.
///
/// Re-exports all platform-agnostic types from `map_utils_core` plus
/// Google Maps–specific widgets, extensions, and overlays.
library;

// Re-export everything from the platform-agnostic core
export 'package:map_utils_core/map_utils_core.dart';

// Google Maps extensions
export 'src/gm_extensions.dart';

// Rendering
export 'src/rendering/gm_shape_renderer.dart';

// Drawing
export 'src/drawing/gm_drawing_controller.dart';
export 'src/drawing/gm_freehand_overlay.dart';

// Editing
export 'src/editing/gm_vertex_overlay.dart';
export 'src/editing/gm_shape_dragger.dart';

// Measurement
export 'src/measurement/gm_measurement_overlay.dart';

// UI
export 'src/ui/gm_geometry_editor.dart';
