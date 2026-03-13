# google_map_utils

A drawing, editing & measurement toolkit for [google_maps_flutter](https://pub.dev/packages/google_maps_flutter). Built on [map_utils_core](https://pub.dev/packages/map_utils_core) algorithms.

[![pub package](https://img.shields.io/pub/v/google_map_utils.svg)](https://pub.dev/packages/google_map_utils)

## Features

| Category | Capabilities |
|---|---|
| **Drawing** | Polygon, polyline, rectangle, circle, freehand |
| **Editing** | Drag vertices, insert midpoints, delete vertices, drag whole shapes |
| **Hole Cutting** | Draw holes inside existing polygons |
| **Selection** | Tap-to-select with hit-testing |
| **Snapping** | Vertex, midpoint, edge, intersection, grid, perpendicular |
| **Measurement** | Distance & area with metric/imperial labels |
| **Undo / Redo** | Full command-pattern history |
| **GeoJSON** | Import & export |

## Quick Start

```yaml
dependencies:
  google_map_utils: ^0.2.0
```

### All-in-one widget

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

### Manual composition

For full control, compose the pieces yourself:

```dart
final controller = GmDrawingController(drawingState: drawingState);
final renderer = GmShapeRenderer(drawingState: drawingState);

Stack(
  children: [
    GoogleMap(
      onMapCreated: controller.onMapCreated,
      onTap: controller.handleTap,
      onLongPress: controller.handleLongPress,
      polygons: renderer.polygons,
      polylines: renderer.polylines,
      circles: renderer.circles,
      scrollGesturesEnabled: !drawingState.shouldAbsorbMapGestures,
    ),
    if (drawingState.activeMode == DrawingMode.freehand)
      GmFreehandOverlay(controller: controller),
    if (drawingState.selectedShape != null)
      GmVertexOverlay(controller: controller),
  ],
)
```

## Architecture

All state management, algorithms, and shape models live in `map_utils_core`. This package adds Google Maps–specific rendering, async coordinate conversion, and overlay widgets.

| Component | Purpose |
|---|---|
| `GmShapeRenderer` | Converts `DrawableShape`s to `Set<Polygon>`, `Set<Polyline>`, `Set<Circle>` |
| `GmDrawingController` | Central controller: tap routing, coordinate conversion, mode dispatch |
| `GmFreehandOverlay` | Listener-based freehand drawing with live preview via CustomPaint |
| `GmVertexOverlay` | Positioned Flutter widgets for vertex/edge handles |
| `GmShapeDragger` | Whole-shape drag via async coordinate conversion |
| `GmMeasurementOverlay` | Measurement labels as positioned widgets |
| `GoogleMapGeometryEditor` | All-in-one wrapper composing all the above |

## License

MIT
