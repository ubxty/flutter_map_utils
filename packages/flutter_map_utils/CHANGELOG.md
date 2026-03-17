# Changelog

## 0.0.3

- Updated README: removed `latlong2` references; `LatLng` and geo types come from `map_utils_core` directly
- Fixed Quick Start import — no longer requires a separate `latlong2` import
- Compatibility table now shows `map_utils_core ^0.0.2` instead of `latlong2`

## 0.0.2

- Depends on `map_utils_core ^0.0.2` — all geo types now available via core

## 0.0.1

- **Monorepo restructure**: Now part of the `map_utils` monorepo alongside `map_utils_core` and `google_map_utils`
- **DRY refactor**: `DrawingToolbar` and `ShapeInfoPanel` moved to `map_utils_core` (re-exported for backward compatibility)
- All core algorithms, models, and state management extracted to `map_utils_core`
- Melos 7 workspace management
- Updated to Dart 3.6.0+ / Flutter 3.27.0+

## 0.1.1

- Initial public release
- **Drawing tools**: polygon, polyline, rectangle, circle, freehand
- **Editing**: vertex drag, edge midpoint insertion, vertex deletion (long-press)
- **Selection**: tap-to-select with hit-testing
- **Snapping engine**: vertex, midpoint, edge, intersection, grid, perpendicular — with configurable priority
- **Measurement**: distance and area measurement with metric/imperial display
- **Undo/redo**: command-pattern history with configurable depth
- **Hole drawing**: cut holes into existing polygons
- **GeoJSON**: full import/export with round-trip fidelity
- **Geometry utilities**: point-in-polygon, centroid, area, length, bounding box, self-intersection detection
- **UI widgets**: DrawingToolbar, ShapeInfoPanel, CoordinateDisplay, FlutterMapGeometryEditor (all-in-one wrapper)
- **Shape styles**: fill, stroke, opacity, selected/hover states, presets, JSON serialization
- **Cross-platform**: Android, iOS, Linux, macOS, Web, Windows
