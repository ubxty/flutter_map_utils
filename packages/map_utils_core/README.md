# map_utils_core

Platform-agnostic geometry algorithms, shape models, drawing state, snapping, undo/redo, GeoJSON utilities, and shared UI widgets. **Zero map-SDK dependency** — works with any map engine.

[![pub package](https://img.shields.io/pub/v/map_utils_core.svg)](https://pub.dev/packages/map_utils_core)

## What's inside?

| Module | Contents |
|---|---|
| **Drawing State** | `DrawingState`, `DrawingMode`, `UndoRedoManager` |
| **Shape Models** | `DrawablePolygon`, `DrawablePolyline`, `DrawableCircle`, `DrawableRectangle` (sealed) |
| **Shape Styles** | `ShapeStyle`, `StrokeType`, resolved/default/selected style cascading |
| **Geometry** | Area, perimeter, distance, centroid, midpoint, simplification, smoothing, point-in-polygon, closest-point-on-segment |
| **GeoJSON** | Import/export via `GeoJsonUtils` (Feature, FeatureCollection) |
| **Snapping** | `SnappingEngine` with vertex, midpoint, edge, intersection, grid, perpendicular snap types |
| **Selection** | `SelectionUtils.findClosestShape()` with configurable tolerance |
| **UI Widgets** | `DrawingToolbar`, `ShapeInfoPanel` — shared across map providers |

## Usage

```dart
import 'package:map_utils_core/map_utils_core.dart';

final state = DrawingState();
state.setMode(DrawingMode.polygon);
state.addDrawingPoint(LatLng(51.5, -0.1));
state.addDrawingPoint(LatLng(51.6, -0.1));
state.addDrawingPoint(LatLng(51.6, 0.0));
final shape = state.finishDrawing(); // DrawablePolygon

// GeoJSON export
final geojson = GeoJsonUtils.toFeatureCollection(state.shapes);

// Undo / Redo
state.undo();
state.redo();
```

Most users should depend on `flutter_map_utils` or `google_map_utils` instead, which re-export everything from this package plus map-specific rendering.

## License

MIT
