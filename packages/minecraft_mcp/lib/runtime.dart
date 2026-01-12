/// Runtime components for MCP-enabled Minecraft mods.
///
/// Import this library in your mod's main.dart to enable MCP control:
///
/// ```dart
/// import 'package:minecraft_mcp/runtime.dart';
///
/// Future<void> main() async {
///   // Initialize MCP runtime (if enabled via environment)
///   await initializeMcpRuntime();
///
///   // Register your mod's blocks, entities, etc.
///   BlockRegistry.register(MyBlock());
/// }
/// ```
///
/// The MCP runtime will only start if the MCP_SERVER_ENABLED environment
/// variable is set to 'true'. This allows the same mod code to work with
/// and without MCP control.
library;

export 'src/runtime/mcp_mod_entry.dart';
export 'src/runtime/mcp_runtime.dart';
