/// Platform-agnostic geometry algorithms, shape models, drawing state,
/// snapping, undo/redo, and GeoJSON utilities.
///
/// This package has zero dependency on any map SDK (flutter_map,
/// google_maps_flutter, etc.). Use it directly for pure algorithm access,
/// or through a binding package like `flutter_map_utils` or
/// `google_map_utils`.
library;

// Core
export 'src/core/drawing_mode.dart';
export 'src/core/drawing_state.dart';
export 'src/core/shape_model.dart';
export 'src/core/shape_style.dart';
export 'src/core/undo_redo_manager.dart';

// Geometry
export 'src/geometry/geometry_utils.dart';
export 'src/geometry/geojson_utils.dart';

// Snapping
export 'src/snapping/snapping_engine.dart';

// Selection
export 'src/selection/selection_utils.dart';
