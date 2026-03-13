/// A reversible command for the undo/redo system.
///
/// Implement [execute] and [undo] for each operation type.
abstract class UndoableCommand {
  /// Human-readable description of this command.
  String get description;

  /// Execute (or re-execute) the command.
  void execute();

  /// Reverse the command.
  void undo();
}

/// Manages an undo/redo stack using the command pattern.
///
/// Commands are executed via [execute], which adds them to the undo stack.
/// [undo] and [redo] traverse the stack. The redo stack is cleared
/// whenever a new command is executed.
class UndoRedoManager {
  final List<UndoableCommand> _undoStack = [];
  final List<UndoableCommand> _redoStack = [];

  /// Maximum number of commands to keep in history.
  final int maxHistoryDepth;

  UndoRedoManager({this.maxHistoryDepth = 100});

  /// Whether there are commands to undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are commands to redo.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Number of commands in the undo stack.
  int get undoCount => _undoStack.length;

  /// Number of commands in the redo stack.
  int get redoCount => _redoStack.length;

  /// Execute a command and push it onto the undo stack.
  ///
  /// Clears the redo stack (no branching history).
  void execute(UndoableCommand command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear();

    // Trim history if over limit.
    if (_undoStack.length > maxHistoryDepth) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo the last command.
  ///
  /// Returns the undone command, or `null` if nothing to undo.
  UndoableCommand? undo() {
    if (!canUndo) return null;
    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
    return command;
  }

  /// Redo the last undone command.
  ///
  /// Returns the redone command, or `null` if nothing to redo.
  UndoableCommand? redo() {
    if (!canRedo) return null;
    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
    return command;
  }

  /// Clear all history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

// -- Built-in command implementations --

/// Command that adds a shape to a shape list.
class AddShapeCommand<T> extends UndoableCommand {
  final List<T> _shapes;
  final T _shape;

  AddShapeCommand({required List<T> shapes, required T shape})
      : _shapes = shapes,
        _shape = shape;

  @override
  String get description => 'Add shape';

  @override
  void execute() => _shapes.add(_shape);

  @override
  void undo() => _shapes.remove(_shape);
}

/// Command that removes a shape from a shape list.
class RemoveShapeCommand<T> extends UndoableCommand {
  final List<T> _shapes;
  final T _shape;
  int _index = -1;

  RemoveShapeCommand({required List<T> shapes, required T shape})
      : _shapes = shapes,
        _shape = shape;

  @override
  String get description => 'Remove shape';

  @override
  void execute() {
    _index = _shapes.indexOf(_shape);
    if (_index >= 0) _shapes.removeAt(_index);
  }

  @override
  void undo() {
    if (_index >= 0 && _index <= _shapes.length) {
      _shapes.insert(_index, _shape);
    } else {
      _shapes.add(_shape);
    }
  }
}

/// Command that replaces one shape with another (e.g. vertex edit).
class UpdateShapeCommand<T> extends UndoableCommand {
  final List<T> _shapes;
  final T _oldShape;
  final T _newShape;
  final bool Function(T a, T b) _matcher;

  UpdateShapeCommand({
    required List<T> shapes,
    required T oldShape,
    required T newShape,
    required bool Function(T a, T b) matcher,
  })  : _shapes = shapes,
        _oldShape = oldShape,
        _newShape = newShape,
        _matcher = matcher;

  @override
  String get description => 'Update shape';

  @override
  void execute() {
    final index = _shapes.indexWhere((s) => _matcher(s, _oldShape));
    if (index >= 0) _shapes[index] = _newShape;
  }

  @override
  void undo() {
    final index = _shapes.indexWhere((s) => _matcher(s, _newShape));
    if (index >= 0) _shapes[index] = _oldShape;
  }
}
