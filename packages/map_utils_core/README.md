# map_utils_core

Platform-agnostic geometry algorithms, shape models, drawing state, snapping, undo/redo, GeoJSON utilities, and shared UI widgets. **Zero map-SDK dependency** — works with any map engine.

[![pub package](https://img.shields.io/pub/v/map_utils_core.svg)](https://pub.dev/packages/map_utils_core)
[![likes](https://img.shields.io/pub/likes/map_utils_core)](https://pub.dev/packages/map_utils_core)
[![pub points](https://img.shields.io/pub/points/map_utils_core)](https://pub.dev/packages/map_utils_core/score)

---

## What is this?

**map_utils_core** is the **shared foundation** of the map-utils ecosystem. It provides all geometry, state management, snapping, and serialization logic with zero dependency on any map SDK.

```
                  map_utils_core
                   ╱           ╲
        flutter_map_utils    google_map_utils
        (flutter_map)        (google_maps_flutter)
```

Most users should depend on [`flutter_map_utils`](https://pub.dev/packages/flutter_map_utils) or [`google_map_utils`](https://pub.dev/packages/google_map_utils) instead — they re-export everything from this package automatically.

Use `map_utils_core` directly if:
- You need geometry algorithms without any Flutter/map dependency
- You're building a custom map engine integration
- You want pure-Dart shape manipulation for a server or CLI

---

## Modules

| Module | Contents |
|---|---|
| **Drawing State** | `DrawingState`, `DrawingMode`, `UndoRedoManager` |
| **Shape Models** | `DrawablePolygon`, `DrawablePolyline`, `DrawableCircle`, `DrawableRectangle` (sealed) |
| **Shape Styles** | `ShapeStyle`, `StrokeType`, resolved/default/selected style cascading, presets |
| **Geometry** | Area, perimeter, distance, centroid, midpoint, simplification, smoothing, point-in-polygon, self-intersection, bounding-box |
| **GeoJSON** | Import/export via `GeoJsonUtils` (Feature, FeatureCollection, string, Map) |
| **Snapping** | `SnappingEngine` with vertex, midpoint, edge, intersection, grid, perpendicular |
| **Selection** | `SelectionUtils.findClosestShape()` with configurable tolerance |
| **UI Widgets** | `DrawingToolbar`, `ShapeInfoPanel` — shared across map providers |
| **Geo Types** | `LatLng`, `Distance` (Haversine & Vincenty), `Path`, `Circle`, `LengthUnit`, `CatmullRomSpline2D` — coordinate & geometry primitives |
| **Enhanced Geo** | `GeoDistance`, `GeoPath`, `GeoCircle`, `GeoBounds` — extended geo utilities built on the primitives above |

---

## Installation

```yaml
dependencies:
  map_utils_core: ^0.0.2
```

> **Tip:** If you use `flutter_map_utils` or `google_map_utils`, this package is already included. All geo types (`LatLng`, `Distance`, `Path`, `Circle`, etc.) are re-exported directly from `map_utils_core` — no additional coordinate package needed.

---

## Drawing State

`DrawingState` is the central `ChangeNotifier` that drives all drawing, editing, selection, and undo.

### Lifecycle

```dart
import 'package:map_utils_core/map_utils_core.dart';

final state = DrawingState();

// 1. Set mode
state.setMode(DrawingMode.polygon);

// 2. Add points (from map taps)
state.addDrawingPoint(LatLng(51.5, -0.1));
state.addDrawingPoint(LatLng(51.6, -0.1));
state.addDrawingPoint(LatLng(51.6, 0.0));

// 3. Finish → produces a DrawablePolygon
final shape = state.finishDrawing();

// 4. Select & edit
state.setMode(DrawingMode.select);
state.selectShape(shape!.id);
state.updateVertexPosition(shape.id, 0, LatLng(51.51, -0.09));

// 5. Undo / redo
state.undo();
state.redo();
```

### Key properties

| Property | Type | Description |
|---|---|---|
| `shapes` | `List<DrawableShape>` | All committed shapes |
| `activeMode` | `DrawingMode` | Current mode (polygon, polyline, select, etc.) |
| `currentPoints` | `List<LatLng>` | Points being drawn (in-progress) |
| `selectedShape` | `DrawableShape?` | Currently selected shape |
| `selectedShapeId` | `String?` | ID of the selected shape |
| `isDrawing` | `bool` | Whether actively drawing |
| `canUndo` / `canRedo` | `bool` | Whether undo/redo is available |
| `shouldAbsorbMapGestures` | `bool` | Whether the map should disable pan/zoom (true during drawing) |

### Shape operations

```dart
// Delete
state.removeShape(shapeId);

// Duplicate
state.duplicateSelected();

// Clear all
state.clearAll();

// Deselect
state.deselectAll();

// Update a vertex
state.updateVertexPosition(shapeId, vertexIndex, newLatLng);
```

### Circles

```dart
state.setMode(DrawingMode.circle);
state.setCircleCenter(LatLng(51.5, -0.1));
state.setCircleRadius(500.0); // meters
state.finishCircleDrawing();
```

### Holes

```dart
state.selectShape(polygonId);
state.setMode(DrawingMode.hole);
state.selectShape(polygonId); // re-select after mode change
state.addDrawingPoint(...); // hole vertices
state.finishHoleDrawing();
```

---

## Shape Styles

### Custom style

```dart
final style = ShapeStyle(
  fillColor: Color(0x554285F4),
  borderColor: Color(0xFF4285F4),
  borderWidth: 2.0,
  fillOpacity: 0.3,
  strokeType: StrokeType.dashed,
  selectedOverride: ShapeStyle(
    borderColor: Color(0xFFFF0000),
    borderWidth: 4.0,
  ),
  hoverOverride: ShapeStyle(
    borderColor: Color(0xFFFFAA00),
  ),
);
```

### Style resolution

`resolve()` cascades overrides based on shape state:

```dart
final resolved = style.resolve(isSelected: true, isHovered: false);
// resolved.borderColor == Color(0xFFFF0000)  (from selectedOverride)
// resolved.fillColor == Color(0x554285F4)    (from base)
```

### Presets

```dart
ShapeStylePresets.zone;               // blue translucent fill
ShapeStylePresets.warning;            // red translucent fill
ShapeStylePresets.route;              // line-only, no fill
ShapeStylePresets.selected;           // selection highlight
ShapeStylePresets.hover;              // hover highlight
ShapeStylePresets.defaultWithStates;  // sensible defaults with selected/hover
```

### JSON serialization

```dart
final json = style.toJson();
final restored = ShapeStyle.fromJson(json);
```

---

## Geometry Utilities

All methods are static on `GeometryUtils`:

### Point-in-polygon

```dart
final inside = GeometryUtils.pointInPolygon(
  LatLng(51.5, -0.1),
  polygonPoints,
);
```

### Area & perimeter

```dart
final areaM2 = GeometryUtils.polygonArea(points);        // square meters
final areaFt2 = GeometryUtils.areaInSquareFeet(areaM2);  // square feet
final acres = GeometryUtils.areaInAcres(areaM2);         // acres
final lengthM = GeometryUtils.polylineLength(points);     // meters
```

### Shape-level (works with any DrawableShape)

```dart
final area = GeometryUtils.shapeArea(someShape);          // square meters
final perimeter = GeometryUtils.shapePerimeter(someShape); // meters
```

### Centroid & midpoint

```dart
final center = GeometryUtils.centroid(points);
final mid = GeometryUtils.midpoint(pointA, pointB);
```

### Distance

```dart
final meters = GeometryUtils.distanceBetween(pointA, pointB);
```

### Nearest point on segment

```dart
final (:point, :t) = GeometryUtils.nearestPointOnSegment(
  cursor, segmentStart, segmentEnd,
);
// point = closest LatLng on the segment
// t = 0..1 parameter along the segment
```

### Self-intersection detection

```dart
final selfIntersects = GeometryUtils.isSelfIntersecting(points);
```

### Winding order

```dart
final cw = GeometryUtils.isClockwise(points);
final ordered = GeometryUtils.ensureClockwise(points);
```

### Path simplification & smoothing

```dart
// Douglas-Peucker simplification
final simplified = GeometryUtils.simplifyPath(points, tolerance: 0.0001);

// Catmull-Rom smoothing
final smooth = GeometryUtils.smoothPath(points, segments: 8);
```

---

## GeoJSON

### Export

```dart
// All shapes → GeoJSON string
final geojsonStr = GeoJsonUtils.toGeoJsonString(state.shapes);

// All shapes → Map (FeatureCollection)
final featureCollection = GeoJsonUtils.toFeatureCollection(state.shapes);

// Single shape → Feature map
final feature = GeoJsonUtils.toGeoJson(oneShape);
```

### Import

```dart
// From string
final shapes = GeoJsonUtils.fromGeoJsonString(geojsonStr);

// From Map
final shapes = GeoJsonUtils.fromGeoJson(featureCollectionMap);
```

### Round-trip fidelity

```dart
final exported = GeoJsonUtils.toGeoJsonString(state.shapes);
final reimported = GeoJsonUtils.fromGeoJsonString(exported);
// reimported is identical to the original shapes
```

---

## Snapping

### Configuration

```dart
final snapEngine = SnappingEngine(
  config: SnapConfig(
    enabled: true,
    toleranceMeters: 15.0,
    priorities: [
      SnapType.vertex,       // snap to existing vertices first
      SnapType.midpoint,     // then to edge midpoints
      SnapType.edge,         // then to nearest point on edge
      SnapType.intersection, // then to edge intersections
      SnapType.grid,         // then to grid
    ],
    gridSpacing: 0.0001,     // ~11m grid at equator
  ),
);
```

### Snap a point

```dart
final result = snapEngine.snap(
  candidatePoint: cursorLatLng,
  shapes: state.shapes,
  excludeShapeId: state.selectedShapeId, // don't snap to itself
);

if (result != null) {
  print(result.type);          // e.g. SnapType.vertex
  print(result.point);         // snapped coordinate
  print(result.distance);      // meters from cursor to snap point
  print(result.sourceShapeId); // which shape it snapped to
}
```

### Snap types

| Type | Behavior |
|---|---|
| `vertex` | Snaps to existing shape vertices |
| `midpoint` | Snaps to the midpoint of each shape edge |
| `edge` | Snaps to the nearest point on any edge |
| `intersection` | Snaps to where two edges cross |
| `grid` | Snaps to a regular lat/lng grid |
| `perpendicular` | Snaps to perpendicular projection on nearby edges |

---

## Selection

### Find closest shape

```dart
final shapeId = SelectionUtils.findClosestShape(
  LatLng(51.5, -0.1),
  state.shapes,
  toleranceMeters: 20.0,
);

if (shapeId != null) {
  state.selectShape(shapeId);
}
```

### Distance to shape

```dart
final dist = SelectionUtils.distanceToShape(
  LatLng(51.5, -0.1),
  someShape,
);
// Returns 0.0 for point inside a polygon
// Returns distance to nearest edge/boundary otherwise
```

---

## Undo / Redo

```dart
final state = DrawingState(maxHistoryDepth: 100);

// Every shape add/remove/update is tracked automatically.
state.undo();
state.redo();

print(state.canUndo); // true
print(state.canRedo); // false
```

---

## Serialization

### Shape JSON

```dart
// Save entire shape list to JSON (preserves styles, holes, all properties)
final json = state.shapesToJson();

// Restore
state.loadShapesFromJson(json);
```

### Style JSON

```dart
final json = myStyle.toJson();
final restored = ShapeStyle.fromJson(json);
```

---

## UI Widgets

### DrawingToolbar

A mode-selector + action buttons widget. Map-engine agnostic — works with any map.

```dart
DrawingToolbar(
  drawingState: state,
  showUndoRedo: true,
  showDelete: true,
  // Customize button appearance:
  buttonBuilder: (context, mode, isActive, onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey,
      ),
      child: Text(mode.name),
    );
  },
)
```

### ShapeInfoPanel

Displays selected shape info: type, area, perimeter, vertex count.

```dart
ShapeInfoPanel(drawingState: state)
```

---

## API Reference

| Class | Purpose |
|---|---|
| `DrawingState` | Central ChangeNotifier: shapes, selection, mode, drawing state, undo/redo |
| `DrawingMode` | Enum: `none`, `polygon`, `polyline`, `rectangle`, `circle`, `freehand`, `select`, `measure`, `hole` |
| `DrawableShape` | Sealed base — `DrawablePolygon`, `DrawablePolyline`, `DrawableCircle`, `DrawableRectangle` |
| `ShapeStyle` | Fill, stroke, opacity, selected/hover overrides, JSON serializable |
| `ShapeStylePresets` | Ready-to-use styles: `zone`, `warning`, `route`, `selected`, `hover`, `defaultWithStates` |
| `StrokeType` | Enum: `solid`, `dashed`, `dotted` |
| `UndoRedoManager` | Command-pattern history (`AddShapeCommand`, `RemoveShapeCommand`, `UpdateShapeCommand`) |
| `GeometryUtils` | 20+ static methods for geometry calculations |
| `GeoJsonUtils` | GeoJSON import/export (string, Map, FeatureCollection) |
| `SnappingEngine` | Priority-based snapping with configurable tolerance and snap types |
| `SnapConfig` | Configuration: enabled, tolerance, priorities, grid spacing |
| `SnapResult` | Snap result: type, point, distance, source shape ID |
| `SnapType` | Enum: `vertex`, `midpoint`, `edge`, `intersection`, `grid`, `perpendicular` |
| `SelectionUtils` | Hit-testing: `findClosestShape()`, `distanceToShape()`, `nearestEdgeDistance()` |
| `DrawingToolbar` | Mode selector with undo/redo/delete — customizable via `buttonBuilder` |
| `ShapeInfoPanel` | Displays selected shape info |
| `LatLng` | Coordinate primitive (re-exported; use this instead of a separate coordinate package) |
| `Distance` | Haversine / Vincenty distance calculations |
| `GeoDistance` | Extended distance: midpoint, interpolate, crossTrackDistance, pathLength, and more |
| `GeoPath` | Enhanced coordinate path with bounds, nearest point, bearings, subPath |
| `GeoCircle` | Circle with `toPolygon()`, `overlaps()`, `toBounds()` |
| `GeoBounds` | Bounding box from points, contains, union, intersection, center |

---

## Compatibility

| Dependency | Version |
|---|---|
| Dart | >= 3.6.0 |
| Flutter | >= 3.27.0 (for UI widgets only) |

---

## About

Built and maintained by **[UBXTY Unboxing Technology](https://ubxty.com/)**.

Part of the [`flutter_map_utils`](https://github.com/ubxty/flutter_map_utils) monorepo.

## License

MIT — see [LICENSE](LICENSE) for details.
