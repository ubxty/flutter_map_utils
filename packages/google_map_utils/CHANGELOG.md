## 0.0.3

- Updated README: removed `latlong2` references throughout; Extension table now references `LatLng` from `map_utils_core`
- Renamed confusing "Migrating from flutter_map_utils" section to "Switching Between Map Engines" with clear guidance on when to use each package
- Compatibility table now shows `map_utils_core ^0.0.2` instead of `latlong2`

## 0.0.2

- Depends on `map_utils_core ^0.0.2` — all geo types now available via core

## 0.0.1

- Initial public release
- Shape rendering: GmShapeRenderer (polygons, polylines, circles)
- Drawing controller with mode-based tap routing
- Freehand drawing overlay with batch coordinate conversion
- Vertex editing overlay with drag, insert, delete handles
- Whole-shape drag overlay
- Measurement overlay with per-segment and total distance labels
- All-in-one GoogleMapGeometryEditor wrapper widget
- Google Maps extensions: StrokeType → PatternItem, LatLng conversions, bounding box
