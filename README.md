# map_utils

A **monorepo** providing drawing, editing & measurement tools for Flutter maps.

| Package | Description | Pub |
|---|---|---|
| [`map_utils_core`](packages/map_utils_core/) | Platform-agnostic algorithms, models & state | [![pub](https://img.shields.io/pub/v/map_utils_core.svg)](https://pub.dev/packages/map_utils_core) |
| [`flutter_map_utils`](packages/flutter_map_utils/) | Widgets & layers for [flutter_map](https://pub.dev/packages/flutter_map) | [![pub](https://img.shields.io/pub/v/flutter_map_utils.svg)](https://pub.dev/packages/flutter_map_utils) |
| [`google_map_utils`](packages/google_map_utils/) | Widgets & overlays for [google_maps_flutter](https://pub.dev/packages/google_maps_flutter) | [![pub](https://img.shields.io/pub/v/google_map_utils.svg)](https://pub.dev/packages/google_map_utils) |

## Features

- **Drawing** — Polygon, polyline, rectangle, circle, freehand
- **Editing** — Drag vertices, insert midpoints, delete vertices, drag whole shapes
- **Holes** — Cut holes inside polygons
- **Snapping** — Vertex, midpoint, edge, intersection, grid, perpendicular
- **Measurement** — Distance & area with metric/imperial labels
- **Undo / Redo** — Full command-pattern history
- **GeoJSON** — Import & export with round-trip fidelity
- **Styles** — Fill, stroke, opacity, selected/hover states, presets, JSON serialization
- **Shared state** — Same `DrawingState` works with both map engines

## Architecture

```
┌────────────────────┐     ┌────────────────────┐
│  flutter_map_utils │     │  google_map_utils   │
│ (flutter_map)      │     │ (google_maps_flutter│
└────────┬───────────┘     └────────┬────────────┘
         │                          │
         └──────────┬───────────────┘
                    │
          ┌─────────┴──────────┐
          │   map_utils_core   │
          │  (pure algorithms) │
          └────────────────────┘
```

All drawing state, shape models, geometry algorithms, undo/redo, snapping,
GeoJSON import/export, and shared UI widgets live in **core** — zero map-SDK
dependency. The binding packages add the map-specific rendering, gesture
handling, and coordinate conversion.

## Quick Start

```yaml
# For flutter_map users
dependencies:
  flutter_map_utils: ^0.2.0

# For Google Maps users
dependencies:
  google_map_utils: ^0.2.0

# For algorithm-only usage
dependencies:
  map_utils_core: ^0.2.0
```

## Development

This repo uses [Melos](https://melos.invertase.dev/) for monorepo management:

```bash
dart pub global activate melos
melos bootstrap
melos run analyze
melos run test
```

## License

MIT — see [LICENSE](LICENSE) in each package.
