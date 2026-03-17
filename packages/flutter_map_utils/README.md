# flutter_map_utils

A powerful drawing, editing & measurement toolkit that extends [flutter_map](https://pub.dev/packages/flutter_map) with professional GIS capabilities.

[![pub package](https://img.shields.io/pub/v/flutter_map_utils.svg)](https://pub.dev/packages/flutter_map_utils)
[![likes](https://img.shields.io/pub/likes/flutter_map_utils)](https://pub.dev/packages/flutter_map_utils)
[![pub points](https://img.shields.io/pub/points/flutter_map_utils)](https://pub.dev/packages/flutter_map_utils/score)
[![stars](https://badgen.net/github/stars/ubxty/flutter_map_utils?label=stars&color=green&icon=github)](https://github.com/ubxty/flutter_map_utils/stargazers)

---

## What is this?

**flutter_map_utils** is an **addon** for `flutter_map` — it does *not* replace it. Drop it into any existing `flutter_map` project and instantly unlock interactive drawing, shape editing, snapping, measurement, and GeoJSON support.

Think of it as a geometry toolbox that sits on top of your map.

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
| **UI Widgets** | Toolbar, info panel, coordinate display — or build your own |
| **Cross-platform** | Android, iOS, Linux, macOS, Web, Windows |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_map_utils: ^0.0.2
```

Then run:

```bash
flutter pub get
```

> **Note:** This package depends on `flutter_map ^8.0.0`. It is pulled in automatically.
>
> This package re-exports everything from [`map_utils_core`](https://pub.dev/packages/map_utils_core) — including `LatLng` and all geo types — so you don't need to add any coordinate package separately. A [`google_map_utils`](https://pub.dev/packages/google_map_utils) package is also available for Google Maps.

---

## Quick Start

### Option A: All-in-one widget

The fastest way to get a full drawing editor on screen:

```dart
import 'package:flutter_map_utils/flutter_map_utils.dart';
import 'package:flutter_map/flutter_map.dart';

final drawingState = DrawingState();

FlutterMapGeometryEditor(
  drawingState: drawingState,
  mapOptions: MapOptions(
    initialCenter: LatLng(51.5, -0.09),
    initialZoom: 13,
  ),
  tileLayer: TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ),
)
```

This gives you a map with a toolbar, drawing layer, selection, editing handles, info panel, and coordinate display — all wired together.

### Option B: Composable layers

For full control, compose the pieces yourself:

```dart
final state = DrawingState();
final layerKey = GlobalKey<DrawingLayerState>();

FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(51.5, -0.09),
    initialZoom: 13,
    onTap: (pos, latlng) => layerKey.currentState?.handleTap(latlng),
    onSecondaryTap: (pos, latlng) =>
        layerKey.currentState?.handleSecondaryTap(latlng),
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    DrawingLayer(key: layerKey, drawingState: state),
    SelectionLayer(drawingState: state),
    EditableShapeLayer(drawingState: state),
  ],
)
```

### Drawing a polygon

```dart
state.setMode(DrawingMode.polygon);

// User taps on the map to add vertices...
// Double-tap or secondary-tap to finish.
// The shape is automatically added to state.shapes.
```

### Editing shapes

```dart
state.setMode(DrawingMode.select);

// Tap a shape to select it.
// Drag vertices to move them.
// Tap edge midpoints to insert new vertices.
// Long-press a vertex to delete it.
```

### Measuring distances

```dart
final measureState = MeasurementState();

// Add to your map:
MeasurementLayer(measurementState: measureState);

// Tap to add measurement points:
measureState.addPoint(LatLng(51.5, -0.09));

print(measureState.totalDistanceMeters); // 1234.5
print(measureState.areaSquareMeters);    // 56789.0
```

### GeoJSON export / import

```dart
// Export all shapes
final geojson = GeoJsonUtils.toGeoJsonString(state.shapes);

// Import from GeoJSON
final shapes = GeoJsonUtils.fromGeoJsonString(geojsonString);
state.loadShapesFromJson(shapes.map((s) => s.toJson()).toList());
```

### Snapping

```dart
final snapEngine = SnappingEngine(
  config: SnapConfig(
    tolerancePixels: 15,
    priorities: [SnapType.vertex, SnapType.midpoint, SnapType.grid],
    gridSpacing: 0.001,
  ),
);

final result = snapEngine.snap(
  candidatePoint: latlng,
  shapes: state.shapes,
);

if (result != null) {
  // result.snappedPoint — the point to use
  // result.type — which snap type matched
}
```

### Undo / Redo

```dart
state.undo();
state.redo();

print(state.undoRedo.canUndo); // true
print(state.undoRedo.canRedo); // false
```

---

## Architecture

```
┌────────────────────────────────────────────────┐
│                  FlutterMap                     │
│  ┌──────────────────────────────────────────┐  │
│  │              TileLayer                   │  │
│  ├──────────────────────────────────────────┤  │
│  │           DrawingLayer                   │  │  ← renders shapes + active tool preview
│  ├──────────────────────────────────────────┤  │
│  │          SelectionLayer                  │  │  ← tap-to-select hit testing
│  ├──────────────────────────────────────────┤  │
│  │        EditableShapeLayer                │  │  ← vertex/edge handles
│  ├──────────────────────────────────────────┤  │
│  │        MeasurementLayer                  │  │  ← distance/area readout
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
         │
    DrawingState (ChangeNotifier)
         │
    UndoRedoManager ← command pattern history
```

**State management:** `DrawingState` is a plain `ChangeNotifier`. Use it with Provider, Riverpod, Bloc, `ListenableBuilder` — whatever you prefer.

---

## API Reference

### Core

| Class | Purpose |
|---|---|
| `DrawingState` | Central state: shapes, selection, mode, undo/redo |
| `DrawingMode` | Enum: `none`, `polygon`, `polyline`, `rectangle`, `circle`, `freehand`, `select`, `measure`, `hole` |
| `DrawableShape` | Sealed base class — `DrawablePolygon`, `DrawablePolyline`, `DrawableCircle`, `DrawableRectangle` |
| `ShapeStyle` | Fill color, stroke color, stroke width, opacity, selected/hover states |
| `UndoRedoManager` | Command-pattern history with `AddShapeCommand`, `RemoveShapeCommand`, `UpdateShapeCommand` |

### Layers

| Widget | Purpose |
|---|---|
| `DrawingLayer` | Renders shapes + active drawing tool preview |
| `SelectionLayer` | Hit-test-based shape selection |
| `EditableShapeLayer` | Vertex handles, edge midpoints, drag editing |
| `MeasurementLayer` | Distance/area measurement overlay |

### Drawing Tools

| Class | Shape |
|---|---|
| `PolygonDrawTool` | Multi-point polygon |
| `PolylineDrawTool` | Multi-point polyline |
| `RectangleDrawTool` | Two-corner rectangle |
| `CircleDrawTool` | Center + radius circle |
| `FreehandDrawTool` | Finger/mouse-path freehand |

### Utilities

| Class | Purpose |
|---|---|
| `GeometryUtils` | `pointInPolygon`, `centroid`, `polygonArea`, `polylineLength`, `boundingBox`, `isSelfIntersecting`, and more |
| `GeoJsonUtils` | `toGeoJson`, `fromGeoJson`, `toGeoJsonString`, `fromGeoJsonString` |
| `SnappingEngine` | Priority-based snapping with vertex, midpoint, edge, intersection, grid, perpendicular modes |
| `SelectionUtils` | Hit-testing: `findClosestShape()`, `distanceToShape()`, `nearestEdgeDistance()` |
| `ShapeStylePresets` | Ready-to-use styles: `zone`, `warning`, `route`, `selected`, `hover`, `defaultWithStates` |

### UI Widgets

| Widget | Purpose |
|---|---|
| `DrawingToolbar` | Mode selector with undo/redo/delete buttons — fully customizable via `buttonBuilder` |
| `ShapeInfoPanel` | Displays selected shape info: type, area, perimeter, coordinates |
| `CoordinateDisplay` | Shows cursor position in DD or DMS format |
| `FlutterMapGeometryEditor` | All-in-one wrapper that composes everything above |

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

## Example App

The [example app](example/) demonstrates every feature in action with a tabbed interface:

- **Drawing** — switch between all drawing modes and draw shapes
- **Editing** — select, drag vertices, insert midpoints, delete vertices
- **Measurement** — tap to measure distances and areas
- **GeoJSON** — export shapes, edit JSON, re-import
- **Snapping** — configure snap priorities and grid spacing
- **All-in-One** — the `FlutterMapGeometryEditor` widget with everything wired

Run the example:

```bash
cd example
flutter run
```

---

## Compatibility

| Dependency | Version |
|---|---|
| Flutter | >= 3.27.0 |
| Dart | >= 3.6.0 |
| flutter_map | ^8.0.0 |
| map_utils_core | ^0.0.2 |

---

## About

Built and maintained by **[UBXTY Unboxing Technology](https://ubxty.com/)**.

Part of the [`flutter_map_utils`](https://github.com/ubxty/flutter_map_utils) monorepo which also includes [`map_utils_core`](https://pub.dev/packages/map_utils_core) and [`google_map_utils`](https://pub.dev/packages/google_map_utils).

---

## Maintainer

**Ravdeep Singh** — [UBXTY Unboxing Technology](https://ubxty.com/)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Ravdeep%20Singh-blue?logo=linkedin)](https://www.linkedin.com/in/ravdeep-singh-a4544abb/)

---

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-thing`)
3. Commit your changes (`git commit -m 'Add amazing thing'`)
4. Push to the branch (`git push origin feature/amazing-thing`)
5. Open a Pull Request

---

## License

MIT — see [LICENSE](LICENSE) for details.
