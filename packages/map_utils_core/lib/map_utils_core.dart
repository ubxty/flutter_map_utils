/// Platform-agnostic geometry algorithms, shape models, drawing state,
/// snapping, undo/redo, and GeoJSON utilities.
///
/// This package has zero dependency on any map SDK (flutter_map,
/// google_maps_flutter, etc.). Use it directly for pure algorithm access,
/// or through a binding package like `flutter_map_utils` or
/// `google_map_utils`.
///
/// **Geo types** — [LatLng], [Distance], [Vincenty], [Haversine],
/// [LengthUnit], [Path], [Circle] are all available directly from this
/// package. No additional geo library required.
///
/// **Enhanced geo classes** — [GeoDistance], [GeoPath], [GeoCircle],
/// [GeoBounds] extend the base types with additional algorithms.
library;

// ── Geo primitives (own the types — no external import needed) ───────────────
export 'package:latlong2/latlong.dart';
export 'package:latlong2/spline.dart' show CatmullRomSpline, CatmullRomSpline2D, Point2D;

// ── Core ─────────────────────────────────────────────────────────────────────
export 'src/core/drawing_mode.dart';
export 'src/core/drawing_state.dart';
export 'src/core/shape_model.dart';
export 'src/core/shape_style.dart';
export 'src/core/undo_redo_manager.dart';

// ── Geometry ─────────────────────────────────────────────────────────────────
export 'src/geometry/geometry_utils.dart';
export 'src/geometry/geojson_utils.dart';

// ── Enhanced geo types ────────────────────────────────────────────────────────
export 'src/geo/latlng_bounds.dart';
export 'src/geo/geo_distance.dart';
export 'src/geo/geo_path.dart';
export 'src/geo/geo_circle.dart';

// ── Snapping ─────────────────────────────────────────────────────────────────
export 'src/snapping/snapping_engine.dart';

// ── Selection ────────────────────────────────────────────────────────────────
export 'src/selection/selection_utils.dart';

// ── UI (shared across map providers) ─────────────────────────────────────────
export 'src/ui/drawing_toolbar.dart';
export 'src/ui/shape_info_panel.dart';
