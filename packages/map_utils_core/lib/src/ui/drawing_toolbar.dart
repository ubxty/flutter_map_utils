import 'package:flutter/widgets.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// A toolbar for selecting drawing modes.
///
/// Renders a row/column of mode buttons that switch the active
/// [DrawingMode] on the provided [DrawingState].
class DrawingToolbar extends StatefulWidget {
  final DrawingState drawingState;

  /// Layout direction.
  final Axis direction;

  /// Available modes to show (defaults to all).
  final List<DrawingMode>? modes;

  /// Builder for custom mode buttons. If null, default icons are used.
  final Widget Function(
    BuildContext context,
    DrawingMode mode,
    bool isActive,
    VoidCallback onTap,
  )? buttonBuilder;

  /// Padding around the toolbar.
  final EdgeInsets padding;

  /// Spacing between buttons.
  final double spacing;

  /// Whether to show undo/redo buttons.
  final bool showUndoRedo;

  /// Whether to show delete button when a shape is selected.
  final bool showDelete;

  const DrawingToolbar({
    super.key,
    required this.drawingState,
    this.direction = Axis.vertical,
    this.modes,
    this.buttonBuilder,
    this.padding = const EdgeInsets.all(8),
    this.spacing = 4,
    this.showUndoRedo = true,
    this.showDelete = true,
  });

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar> {
  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(DrawingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawingState != widget.drawingState) {
      oldWidget.drawingState.removeListener(_onStateChanged);
      widget.drawingState.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.drawingState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final modes = widget.modes ?? DrawingMode.values;
    final currentMode = widget.drawingState.activeMode;

    final buttons = <Widget>[];

    for (final mode in modes) {
      final isActive = mode == currentMode;
      final button = widget.buttonBuilder != null
          ? widget.buttonBuilder!(
              context,
              mode,
              isActive,
              () => widget.drawingState.setMode(mode),
            )
          : _DefaultModeButton(
              mode: mode,
              isActive: isActive,
              onTap: () => widget.drawingState.setMode(mode),
            );
      buttons.add(button);
    }

    // Undo/Redo
    if (widget.showUndoRedo) {
      buttons.add(SizedBox(
        width: widget.direction == Axis.horizontal ? widget.spacing * 2 : 0,
        height: widget.direction == Axis.vertical ? widget.spacing * 2 : 0,
      ));
      buttons.add(_ActionButton(
        label: '↩',
        enabled: widget.drawingState.undoRedo.canUndo,
        onTap: widget.drawingState.undo,
      ));
      buttons.add(_ActionButton(
        label: '↪',
        enabled: widget.drawingState.undoRedo.canRedo,
        onTap: widget.drawingState.redo,
      ));
    }

    // Delete
    if (widget.showDelete && widget.drawingState.selectedShape != null) {
      buttons.add(_ActionButton(
        label: '✕',
        enabled: true,
        onTap: widget.drawingState.removeSelected,
      ));
    }

    return Padding(
      padding: widget.padding,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF0FFFFFF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: widget.direction == Axis.vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: _addSpacing(buttons, widget.spacing),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: _addSpacing(buttons, widget.spacing),
              ),
      ),
    );
  }

  List<Widget> _addSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) return widgets;
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(SizedBox(width: spacing, height: spacing));
      }
    }
    return result;
  }
}

/// Default labels for drawing modes (text-based, no material icons).
String _modeLabel(DrawingMode mode) => switch (mode) {
      DrawingMode.none => '▫',
      DrawingMode.polygon => '⬠',
      DrawingMode.polyline => '╲',
      DrawingMode.rectangle => '▭',
      DrawingMode.circle => '○',
      DrawingMode.freehand => '✎',
      DrawingMode.select => '↖',
      DrawingMode.measure => '📏',
      DrawingMode.hole => '◌',
    };

class _DefaultModeButton extends StatelessWidget {
  final DrawingMode mode;
  final bool isActive;
  final VoidCallback onTap;

  const _DefaultModeButton({
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2196F3)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          _modeLabel(mode),
          style: TextStyle(
            fontSize: 18,
            color: isActive
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            color: enabled
                ? const Color(0xFF333333)
                : const Color(0xFFBBBBBB),
          ),
        ),
      ),
    );
  }
}
