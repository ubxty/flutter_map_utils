# google_map_utils

A drawing, editing & measurement toolkit for [google_maps_flutter](https://pub.dev/packages/google_maps_flutter). Built on [map_utils_core](https://pub.dev/packages/map_utils_core) algorithms.

[![pub package](https://img.shields.io/pub/v/google_map_utils.svg)](https://pub.dev/packages/google_map_utils)
[![likes](https://img.shields.io/pub/likes/google_map_utils)](https://pub.dev/packages/google_map_utils)
[![pub points](https://img.shields.io/pub/points/google_map_utils)](https://pub.dev/packages/google_map_utils/score)

---

## What is this?

**google_map_utils** is an **addon** for `google_maps_flutter` — it does *not* replace it. Drop it into any existing Google Maps project and instantly unlock interactive drawing, shape editing, snapping, measurement, and GeoJSON support.

Same drawing state, same algorithms, same GeoJSON — just a different map engine. If you use `flutter_map`, see [`flutter_map_utils`](https://pub.dev/packages/flutter_map_utils) instead.

---

## Features

| Category | Capabilities |
|---|---|
| **Drawing** | Polygon, polyline, rectangle, circle, freehand — tap or drag to draw |
| **Editing** | Drag vertices, insert midpoints, delete vertices (long-press), drag whole shapes |
| **Hole Cutting** | Draw holes inside existing polygons |
| **Selection** | Tap-to-select with hit-testing on edges and fills |
| **Snapping** | Vertex, midpoint, edge, intersection, grid, perpendicular — priority-based |
| **Measurement** | Distance & area with metric/imperial labels, per-segment display |
| **Undo / Redo** | Full command-pattern history with configurable depth |
| **GeoJSON** | Import & export with round-trip fidelity (string or Map) |
| **Geometry** | Point-in-polygon, centroid, area, length, bounding box, self-intersection detection |
| **Styles** | Fill, stroke, opacity, selected/hover states, presets, JSON serialization |
| **UI Widgets** | Toolbar, info panel — or build your own |
| **Cross-platform** | Android, iOS, Web |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  google_map_utils: ^0.2.0
```

Then run:

```bash
flutter pub get
```

> **Note:** This package depends on `google_maps_flutter ^2.10.0` and `latlong2 ^0.9.1`. Both are pulled in automatically.
>
> **Platform setup:** You still need a Google Maps API key configured per the [google_maps_flutter setup guide](https://pub.dev/packages/google_maps_flutter#getting-started).

---

## Quick Start

### Option A: All-in-one widget

The fastest way to get a full drawing editor on screen:

```dart
import 'package:google_map_utils/google_map_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final drawingState = DrawingState();

GoogleMapGeometryEditor(
  drawingState: drawingState,
  initialCameraPosition: CameraPosition(
    target: LatLng(51.5, -0.1),
    zoom: 12,
  ),
)
```

This gives you a Google Map with a toolbar, drawing layer, selection, editing handles, info panel, and measurement — all wired together.

### Option B: Manual composition

For full control, compose the pieces yourself inside a `Stack`:

```dart
final drawingState = DrawingState();
final controller = GmDrawingController(drawingState: drawingState);
final renderer = GmShapeRenderer(
  drawingState: drawingState,
  onShapeTap: (id) => drawingState.selectShape(id),
);

Stack(
  children: [
    GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(51.5, -0.1),
        zoom: 12,
      ),
      onMapCreated: controller.onMapCreated,
      onTap: controller.handleTap,
      onLongPress: controller.handleLongPress,
      onCameraMove: (_) => controller.onCameraChanged(),
      polygons: renderer.polygons,
      polylines: renderer.polylines,
      circles: renderer.circles,
      scrollGesturesEnabled: !drawingState.shouldAbsorbMapGestures,
      zoomGesturesEnabled: !drawingState.shouldAbsorbMapGestures,
      rotateGesturesEnabled: !drawingState.shouldAbsorbMapGestures,
      tiltGesturesEnabled: !drawingState.shouldAbsorbMapGestures,
    ),

    // Freehand drawing (only when in freehand mode)
    if (drawingState.activeMode == DrawingMode.freehand)
      GmFreehandOverlay(controller: controller),

    // Vertex editing handles (only when a shape is selected)
    if (drawingState.selectedShape != null && !drawingState.isDrawing)
      GmVertexOverlay(controller: controller),

    // Whole-shape dragging
    if (drawingState.selectedShape != null && !drawingState.isDrawing)
      GmShapeDragger(controller: controller),

    // Toolbar
    DrawingToolbar(drawingState: drawingState),
  ],
)
```

---

## Drawing Shapes

### Polygon

```dart
drawingState.setMode(DrawingMode.polygon);
// User taps on the map to add vertices.
// Long-press to finish the polygon.
// Or call: controller.finishDrawing();
```

### Polyline

```dart
drawingState.setMode(DrawingMode.polyline);
// Each tap adds a point. Long-press to finish.
```

### Rectangle

```dart
drawingState.setMode(DrawingMode.rectangle);
// First tap = corner A, second tap = corner B → auto-finishes.
```

### Circle

```dart
drawingState.setMode(DrawingMode.circle);
// First tap = center, second tap = radius → auto-finishes.
```

### Freehand

```dart
drawingState.setMode(DrawingMode.freehand);
// The GmFreehandOverlay captures pointer drag → collects screen coordinates
// → batch-converts to LatLng on pointer-up → simplifies → smooths → commits.
```

---

## Editing Shapes

```dart
drawingState.setMode(DrawingMode.select);

// Tap a shape to select it.
// GmVertexOverlay renders draggable handles at every vertex.
// Drag a vertex to move it.
// Tap an edge midpoint to insert a new vertex.
// Long-press a vertex to delete it (min vertex count enforced).
// GmShapeDragger lets you drag the whole shape.
```

---

## Cutting Holes

```dart
// First, select a polygon:
drawingState.selectShape(polygonId);
drawingState.setMode(DrawingMode.hole);
drawingState.selectShape(polygonId); // re-select after mode change

// Each tap adds a hole vertex. Long-press to finish.
// The hole is cut from the selected polygon.
```

---

## Measurement

```dart
final measureState = GmMeasurementState();

// In your GoogleMapGeometryEditor:
GoogleMapGeometryEditor(
  drawingState: drawingState,
  measurementState: measureState,
  initialCameraPosition: ...,
)

// Or add manually to your Stack:
// 1. Add the measurement polyline:
polylines.addAll(GmMeasurementOverlay.buildMeasurementPolyline(measureState));
// 2. Add the label overlay:
GmMeasurementOverlay(
  measurementState: measureState,
  controller: controller,
  unit: GmMeasurementUnit.metric, // or .imperial
)

// Tap on the map in measure mode to add points:
drawingState.setMode(DrawingMode.measure);

// Read values:
print(measureState.totalDistanceMeters); // 1234.5
print(measureState.areaSquareMeters);    // 56789.0
print(measureState.segmentDistances);    // [500.2, 734.3]
```

---

## GeoJSON Export / Import

```dart
// Export all shapes to GeoJSON string
final geojson = GeoJsonUtils.toGeoJsonString(drawingState.shapes);

// Export to Map
final map = GeoJsonUtils.toFeatureCollection(drawingState.shapes);

// Import from GeoJSON string
final shapes = GeoJsonUtils.fromGeoJsonString(geojsonString);
drawingState.loadShapesFromJson(shapes.map((s) => s.toJson()).toList());
```

---

## Snapping

```dart
final snapEngine = SnappingEngine(
  config: SnapConfig(
    tolerancePixels: 15,
    priorities: [SnapType.vertex, SnapType.midpoint, SnapType.grid],
    gridSpacing: 0.001,
  ),
);

final result = snapEngine.snap(
  candidatePoint: someLatLng,
  shapes: drawingState.shapes,
);

if (result != null) {
  // Use result.point — the snapped coordinate
  // result.type — which snap type matched
}
```

---

## Shape Styles

```dart
// Custom style
final style = ShapeStyle(
  fillColor: Color(0x5500FF00),
  borderColor: Color(0xFF00FF00),
  borderWidth: 3.0,
  fillOpacity: 0.3,
  strokeType: StrokeType.dashed,
  selectedOverride: ShapeStyle(
    borderColor: Color(0xFFFF0000),
    borderWidth: 4.0,
  ),
);

drawingState.defaultStyle = style;

// Or use presets
drawingState.defaultStyle = ShapeStylePresets.zone;     // blue fill
drawingState.defaultStyle = ShapeStylePresets.warning;   // red fill
drawingState.defaultStyle = ShapeStylePresets.route;     // line-only
```

---

## Undo / Redo

```dart
drawingState.undo();
drawingState.redo();

print(drawingState.canUndo); // true
print(drawingState.canRedo); // false

// History depth is configurable:
final state = DrawingState(maxHistoryDepth: 50);
```

---

## Serialization

```dart
// Save shapes to JSON
final json = drawingState.shapesToJson();

// Restore shapes from JSON
drawingState.loadShapesFromJson(json);

// Clear everything
drawingState.clearAll();
```

---

## Architecture

```
┌──────────────────────────────────────────┐
│              Stack                        │
│  ┌────────────────────────────────────┐  │
│  │           GoogleMap(               │  │
│  │             polygons: renderer.*   │  │  ← native Google Maps shapes
│  │             polylines: renderer.*  │  │
│  │             circles: renderer.*    │  │
│  │           )                        │  │
│  ├────────────────────────────────────┤  │
│  │       GmFreehandOverlay            │  │  ← freehand drawing preview
│  ├────────────────────────────────────┤  │
│  │        GmVertexOverlay             │  │  ← vertex/edge handles
│  ├────────────────────────────────────┤  │
│  │        GmShapeDragger              │  │  ← whole-shape drag
│  ├────────────────────────────────────┤  │
│  │     GmMeasurementOverlay           │  │  ← measurement labels
│  ├────────────────────────────────────┤  │
│  │     DrawingToolbar + ShapeInfoPanel│  │  ← shared UI widgets
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
         │
    DrawingState (ChangeNotifier)
         │
    UndoRedoManager ← command pattern history
```

**State management:** `DrawingState` is a plain `ChangeNotifier`. Use it with Provider, Riverpod, Bloc, `ListenableBuilder` — whatever you prefer.

**Coordinate conversion:** Google Maps uses async coordinate conversion (`getLatLng` / `getScreenCoordinate`). All overlays handle this internally — you don't need to think about it.

---

## API Reference

### Core (re-exported from `map_utils_core`)

| Class | Purpose |
|---|---|
| `DrawingState` | Central state: shapes, selection, mode, undo/redo |
| `DrawingMode` | Enum: `none`, `polygon`, `polyline`, `rectangle`, `circle`, `freehand`, `select`, `measure`, `hole` |
| `DrawableShape` | Sealed base class — `DrawablePolygon`, `DrawablePolyline`, `DrawableCircle`, `DrawableRectangle` |
| `ShapeStyle` | Fill color, stroke color, stroke width, opacity, selected/hover states, JSON serializable |
| `UndoRedoManager` | Command-pattern history with `AddShapeCommand`, `RemoveShapeCommand`, `UpdateShapeCommand` |
| `GeometryUtils` | `pointInPolygon`, `centroid`, `polygonArea`, `polylineLength`, `simplifyPath`, `smoothPath`, and more |
| `GeoJsonUtils` | `toGeoJson`, `fromGeoJson`, `toGeoJsonString`, `fromGeoJsonString`, `toFeatureCollection` |
| `SnappingEngine` | Priority-based snapping: vertex, midpoint, edge, intersection, grid, perpendicular |
| `SelectionUtils` | `findClosestShape()` with configurable tolerance |

### Google Maps Widgets

| Widget / Class | Purpose |
|---|---|
| `GoogleMapGeometryEditor` | All-in-one wrapper that composes everything below |
| `GmShapeRenderer` | Converts `DrawableShape` list → `Set<Polygon>`, `Set<Polyline>`, `Set<Circle>` |
| `GmDrawingController` | Tap routing, coordinate conversion, mode dispatch, circle preview |
| `GmFreehandOverlay` | Listener-based freehand with live `CustomPaint` preview |
| `GmVertexOverlay` | Positioned vertex/edge handles — drag, insert, delete |
| `GmShapeDragger` | Whole-shape drag via async coordinate conversion |
| `GmMeasurementOverlay` | Per-segment distance labels + total distance + area |
| `GmMeasurementState` | Pure `ChangeNotifier` for measurement points and calculations |

### Shared UI Widgets (from core)

| Widget | Purpose |
|---|---|
| `DrawingToolbar` | Mode selector with undo/redo/delete buttons — fully customizable via `buttonBuilder` |
| `ShapeInfoPanel` | Displays selected shape info: type, area, perimeter, coordinates |

### Extensions

| Extension | Purpose |
|---|---|
| `StrokeTypeToGmPattern` | Converts `StrokeType` → `List<PatternItem>` for polylines |
| `LatLngToGm` | Converts `latlong2.LatLng` → `google_maps.LatLng` |
| `GmLatLngToCore` | Converts `google_maps.LatLng` → `latlong2.LatLng` |
| `LatLngListToGm` | Converts `List<latlong2.LatLng>` → `List<google_maps.LatLng>` |
| `GmGeometryUtils` | `boundingBox()` → `LatLngBounds` from a list of points |

---

## Supported Shape Types

| Shape | Drawing | Editing | GeoJSON | Holes |
|---|---|---|---|---|
| Polygon | ✅ | ✅ | ✅ | ✅ |
| Polyline | ✅ | ✅ | ✅ | — |
| Rectangle | ✅ | ✅ | ✅ | — |
| Circle | ✅ | ✅ | ✅ | — |
| Freehand | ✅ | ✅ | ✅ (as polyline) | — |

---

## Compatibility

| Dependency | Version |
|---|---|
| Flutter | >= 3.27.0 |
| Dart | >= 3.6.0 |
| google_maps_flutter | ^2.10.0 |
| latlong2 | ^0.9.1 |

---

## Migrating from flutter_map_utils

Switching from `flutter_map` to `google_maps_flutter`? The shared `DrawingState` means you can:

1. Replace `flutter_map_utils` with `google_map_utils` in your pubspec
2. Replace `FlutterMapGeometryEditor` with `GoogleMapGeometryEditor`
3. Keep the same `DrawingState`, `ShapeStyle`, `GeoJsonUtils`, snapping, and undo/redo code

Your shapes, styles, GeoJSON exports, and state management stay identical.

---

## About

Built and maintained by **[UBXTY Unboxing Technology](https://ubxty.com/)**.

Part of the [`flutter_map_utils`](https://github.com/ubxty/flutter_map_utils) monorepo.

---

## License

MIT — see [LICENSE](LICENSE) for details.
