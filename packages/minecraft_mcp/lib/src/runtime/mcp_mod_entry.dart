import 'package:dart_mod_common/src/jni/jni_internal.dart';

import 'mcp_runtime.dart';

/// Global MCP runtime instance.
McpRuntime? _mcpRuntime;

/// Check if MCP runtime is enabled.
///
/// Returns true if the MCP_MODE JVM system property is set to 'true'.
/// This is checked via JNI bridge to the Java side.
bool get isMcpEnabled {
  try {
    return GenericJniBridge.callStaticBoolMethod(
      'com/redstone/DartBridge',
      'isMcpModeEnabled',
      '()Z',
      [],
    );
  } catch (_) {
    return false;
  }
}

/// Get the MCP server port from JVM system property.
///
/// Returns the MCP_SERVER_PORT JVM property as an int,
/// or the default port (8765) if not set.
int get mcpServerPort {
  try {
    return GenericJniBridge.callStaticIntMethod(
      'com/redstone/DartBridge',
      'getMcpServerPort',
      '()I',
      [],
    );
  } catch (_) {
    return 8765;
  }
}

/// Get the active MCP runtime instance.
///
/// Returns null if MCP is not enabled or not yet initialized.
McpRuntime? get mcpRuntime => _mcpRuntime;

/// Initialize MCP runtime if enabled.
///
/// Call this from your mod's main() to enable MCP control when the
/// MCP_MODE JVM property is set.
///
/// Example:
/// ```dart
/// import 'package:minecraft_mcp/runtime.dart';
///
/// Future<void> main() async {
///   // Initialize MCP runtime (if enabled via JVM property)
///   initializeMcpRuntime();
///
///   // Register your mod's blocks, entities, etc.
///   BlockRegistry.register(MyBlock());
/// }
/// ```
///
/// The MCP runtime will:
/// 1. Check if MCP_MODE=true (JVM system property)
/// 2. Wait for the Minecraft client to be ready
/// 3. Start the HTTP game server on MCP_SERVER_PORT (default 8765)
/// 4. Print "[MCP] Server ready on port XXXX" marker
///
/// The external MCP server watches for this marker to know when
/// Minecraft is ready to accept commands.
void initializeMcpRuntime({int? port}) {
  if (!isMcpEnabled) {
    // ignore: avoid_print
    print('[MCP] MCP mode not enabled, skipping runtime initialization');
    return; // MCP not enabled, skip initialization
  }

  final serverPort = port ?? mcpServerPort;
  // ignore: avoid_print
  print('[MCP] MCP mode enabled, initializing runtime on port $serverPort');

  // Create and initialize the runtime
  _mcpRuntime = McpRuntime(port: serverPort);

  try {
    _mcpRuntime!.initialize();
  } catch (e) {
    // If we're not running inside Minecraft, just log and continue
    // This allows the same mod code to work with and without MCP
    // ignore: avoid_print
    print('[MCP] Failed to initialize: $e');
    _mcpRuntime = null;
  }
}

/// Shutdown the MCP runtime.
///
/// Call this when your mod is unloading to clean up resources.
/// This is optional as Minecraft process termination will clean up anyway.
Future<void> shutdownMcpRuntime() async {
  await _mcpRuntime?.shutdown();
  _mcpRuntime = null;
}
