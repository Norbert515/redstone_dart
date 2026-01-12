/// MCP server for AI agents to control Minecraft.
///
/// This library provides an MCP (Model Context Protocol) server that allows
/// AI agents to interact with Minecraft through a standardized tool interface.
library;

// MCP server
export 'src/server/mcp_server.dart';
export 'src/server/tool_registry.dart';

// Protocol types
export 'src/protocol/game_protocol.dart';
export 'src/protocol/game_server.dart';

// Minecraft client and controller
export 'src/minecraft/game_client.dart';
export 'src/minecraft/minecraft_controller.dart';
