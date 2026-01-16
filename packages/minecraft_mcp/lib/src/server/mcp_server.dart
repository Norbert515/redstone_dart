import 'dart:convert';
import 'dart:io';

import '../minecraft/minecraft_controller.dart';
import 'tool_registry.dart';

/// MCP server implementing JSON-RPC 2.0 over stdio.
///
/// This server handles the Model Context Protocol for AI agent communication,
/// providing tools to control Minecraft.
class McpServer {
  /// Port for connecting to the game server.
  final int gameServerPort;

  /// Registry of available tools.
  late final ToolRegistry _toolRegistry;

  /// Whether the server has been initialized.
  bool _initialized = false;

  /// Server info returned during initialization.
  static const _serverInfo = {
    'name': 'minecraft-mcp',
    'version': '0.1.0',
  };

  /// Server capabilities.
  static const Map<String, Object> _capabilities = {
    'tools': <String, Object>{},
  };

  McpServer({
    this.gameServerPort = 8765,
  }) {
    _toolRegistry = ToolRegistry(
      defaultPort: gameServerPort,
    );
  }

  /// Controller for managing Minecraft lifecycle (created by startMinecraft tool).
  MinecraftController? get minecraftController => _toolRegistry.minecraftController;

  /// Run the MCP server, reading from stdin and writing to stdout.
  Future<void> run() async {
    // Read JSON-RPC messages from stdin
    await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) continue;

      try {
        final request = jsonDecode(line) as Map<String, dynamic>;
        final response = await _handleRequest(request);
        if (response != null) {
          stdout.writeln(jsonEncode(response));
        }
      } catch (e, stack) {
        stderr.writeln('Error processing request: $e');
        stderr.writeln(stack);
      }
    }
  }

  /// Handle a JSON-RPC request.
  Future<Map<String, dynamic>?> _handleRequest(Map<String, dynamic> request) async {
    final jsonrpc = request['jsonrpc'];
    final method = request['method'] as String?;
    final params = request['params'] as Map<String, dynamic>?;
    final id = request['id'];

    // Notifications don't have an id and don't expect a response
    final isNotification = id == null;

    if (jsonrpc != '2.0') {
      return _errorResponse(id, -32600, 'Invalid Request: jsonrpc must be "2.0"');
    }

    if (method == null) {
      return _errorResponse(id, -32600, 'Invalid Request: method is required');
    }

    try {
      final result = await _dispatch(method, params ?? {});
      if (isNotification) return null;
      return _successResponse(id, result);
    } on _RpcError catch (e) {
      if (isNotification) return null;
      return _errorResponse(id, e.code, e.message, data: e.data);
    } catch (e) {
      if (isNotification) return null;
      return _errorResponse(id, -32603, 'Internal error: $e');
    }
  }

  /// Dispatch a method call to the appropriate handler.
  Future<dynamic> _dispatch(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'initialize':
        return _handleInitialize(params);
      case 'initialized':
        // Notification from client that initialization is complete
        return null;
      case 'tools/list':
        return _handleToolsList();
      case 'tools/call':
        return _handleToolsCall(params);
      case 'ping':
        return {};
      default:
        throw _RpcError(-32601, 'Method not found: $method');
    }
  }

  /// Handle the initialize request.
  Map<String, dynamic> _handleInitialize(Map<String, dynamic> params) {
    if (_initialized) {
      throw _RpcError(-32600, 'Server already initialized');
    }
    _initialized = true;

    return {
      'protocolVersion': '2024-11-05',
      'serverInfo': _serverInfo,
      'capabilities': _capabilities,
    };
  }

  /// Handle tools/list request.
  Map<String, dynamic> _handleToolsList() {
    _ensureInitialized();
    return {
      'tools': _toolRegistry.listTools(),
    };
  }

  /// Handle tools/call request.
  Future<Map<String, dynamic>> _handleToolsCall(Map<String, dynamic> params) async {
    _ensureInitialized();

    final name = params['name'] as String?;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    if (name == null) {
      throw _RpcError(-32602, 'Invalid params: name is required');
    }

    final result = await _toolRegistry.callTool(name, arguments);
    return result;
  }

  /// Ensure the server has been initialized.
  void _ensureInitialized() {
    if (!_initialized) {
      throw _RpcError(-32600, 'Server not initialized');
    }
  }

  /// Create a success response.
  Map<String, dynamic> _successResponse(dynamic id, dynamic result) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };
  }

  /// Create an error response.
  Map<String, dynamic> _errorResponse(
    dynamic id,
    int code,
    String message, {
    dynamic data,
  }) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      },
    };
  }
}

/// Internal RPC error class.
class _RpcError implements Exception {
  final int code;
  final String message;
  final dynamic data;

  _RpcError(this.code, this.message, {this.data});
}
