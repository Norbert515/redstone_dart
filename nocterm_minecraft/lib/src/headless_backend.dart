import 'package:nocterm/src/size.dart';
import 'package:nocterm/src/backend/terminal_backend.dart';

/// A headless terminal backend for rendering without a real terminal.
/// Used to run nocterm apps and capture buffer output.
class HeadlessBackend implements TerminalBackend {
  Size _size;

  HeadlessBackend({Size size = const Size(40, 20)}) : _size = size;

  @override
  void writeRaw(String data) {
    // No-op - we capture via onBufferPainted instead
  }

  @override
  Size getSize() => _size;

  @override
  bool get supportsSize => true;

  @override
  Stream<List<int>>? get inputStream => null;

  @override
  Stream<Size>? get resizeStream => null;

  @override
  Stream<void>? get shutdownStream => null;

  @override
  void enableRawMode() {}

  @override
  void disableRawMode() {}

  @override
  bool get isAvailable => true;

  @override
  void requestExit([int exitCode = 0]) {}

  @override
  void notifySizeChanged(Size newSize) {
    _size = newSize;
  }

  @override
  void dispose() {}
}
