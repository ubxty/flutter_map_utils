## 0.0.3

- Updated README: document `GeoDistance`, `GeoPath`, `GeoCircle`, `GeoBounds` in Modules and API Reference tables
- README now explicitly notes that `LatLng` and all geo types are re-exported from this package — no external coordinate package required
- Removed `latlong2` from the Compatibility table in README (it remains an internal transitive dependency)

## 0.0.2

- **Geo types bundled**: `LatLng`, `Distance`, `Path`, `Circle`, `LengthUnit`,
  `Vincenty`, `Haversine`, `CatmullRomSpline2D` now exported directly from
  `map_utils_core` — no separate geo library required in your pubspec
- **`GeoDistance`**: extended `Distance` with `midpoint`, `interpolate`,
  `crossTrackDistance`, `alongTrackDistance`, `angularDistance`, `pathLength`,
  `pointAlongPath`
- **`GeoPath`**: typed coordinate list with `bounds`, `reverse`, `subPath`,
  `nearest`, `bearing`, `bearings`, `equalize` (CatmullRom smoothing)
- **`GeoCircle`**: extended `Circle` with `toPolygon(steps)`, `overlaps`,
  `containsCircle`, `toBounds`, `distanceToEdge`
- **`GeoBounds`**: axis-aligned geographic bounding box with `extend`, `union`,
  `intersection`, `contains`, `overlaps`, `containsBounds`

## 0.0.1

- Initial public release
- Drawing state with mode management and undo/redo
- Sealed shape models: polygon, polyline, circle, rectangle
- Shape styles with stroke type, border color, fill color, selected state
- Geometry utilities: area, perimeter, distance, centroid, midpoint, simplify, smooth
- GeoJSON import/export
- Snapping engine: vertex, midpoint, edge, intersection, grid, perpendicular
- Selection utilities with closest-shape hit testing
- Shared UI widgets: DrawingToolbar, ShapeInfoPanel
