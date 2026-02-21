import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ai_mode.dart';
import 'native_bridge.dart';

/// Provider for managing AI Gateway state and operations
class AIGatewayProvider extends ChangeNotifier {
  AIGatewayState _state = const AIGatewayState();
  Timer? _healthTimer;
  StreamSubscription? _logSubscription;
  WebSocketChannel? _wsChannel;
  final _responseController = StreamController<String>.broadcast();

  AIGatewayState get state => _state;
  Stream<String> get responseStream => _responseController.stream;

  /// Initialize gateway and check status
  Future<void> init() async {
    final isRunning = await NativeBridge.isGatewayRunning();
    if (isRunning) {
      _updateState(_state.copyWith(
        status: GatewayStatus.running,
        logs: [..._state.logs, '[INFO] Gateway already running'],
      ));
      _startHealthCheck();
      _connectWebSocket();
      await fetchModels();
    }
  }

  /// Start the unified gateway
  Future<void> start() async {
    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      clearError: true,
      logs: [..._state.logs, '[INFO] Starting Unified AI Gateway...'],
    ));

    try {
      await NativeBridge.startGateway();
      _subscribeLogs();
      _startHealthCheck();
      _connectWebSocket();
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to start: $e',
        logs: [..._state.logs, '[ERROR] $e'],
      ));
    }
  }

  /// Stop the gateway
  Future<void> stop() async {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _wsChannel?.sink.close();

    try {
      await NativeBridge.stopGateway();
      _updateState(AIGatewayState(
        status: GatewayStatus.stopped,
        logs: [..._state.logs, '[INFO] Gateway stopped'],
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to stop: $e',
      ));
    }
  }

  /// Switch AI mode
  void setMode(AIMode mode) {
    _updateState(_state.copyWith(currentMode: mode));
    
    // Update routing on gateway
    _updateRouting(mode);
  }

  /// Fetch available models from Ollama
  Future<void> fetchModels() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:18789/models'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List)
            .map((m) => OllamaModel.fromJson(m))
            .toList();
        _updateState(_state.copyWith(availableModels: models));
      }
    } catch (e) {
      _updateState(_state.copyWith(ollamaConnected: false));
    }
  }

  /// Pull a new model
  Future<void> pullModel(String modelName) async {
    _addLog('[INFO] Pulling model: $modelName...');
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:18789/models/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      ).timeout(const Duration(minutes: 30));

      if (response.statusCode == 200) {
        _addLog('[INFO] Model $modelName pulled successfully');
        await fetchModels();
      }
    } catch (e) {
      _addLog('[ERROR] Failed to pull model: $e');
    }
  }

  /// Send chat message
  Future<void> sendChat(String message, {List<Map<String, String>>? history}) async {
    if (_wsChannel == null) {
      _addLog('[ERROR] WebSocket not connected');
      return;
    }

    _wsChannel!.sink.add(jsonEncode({
      'type': 'chat',
      'content': message,
      'history': history ?? [],
      'options': {
        'model': _state.currentMode.defaultModel,
      },
    }));
  }

  /// Send code generation request
  Future<void> sendCodeRequest(String prompt, {bool advanced = false}) async {
    if (_wsChannel == null) {
      _addLog('[ERROR] WebSocket not connected');
      return;
    }

    _wsChannel!.sink.add(jsonEncode({
      'type': 'code',
      'prompt': prompt,
      'options': {
        'advanced': advanced,
        'model': advanced 
          ? AIMode.advancedCode.defaultModel 
          : AIMode.code.defaultModel,
      },
    }));
  }

  /// HTTP-based chat (for non-streaming)
  Future<String> chatHttp(String message, {List<Map<String, String>>? history}) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:18789/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'history': history ?? [],
          'options': {'model': _state.currentMode.defaultModel},
        }),
      ).timeout(const Duration(minutes: 5));

      return response.body;
    } catch (e) {
      _addLog('[ERROR] Chat failed: $e');
      rethrow;
    }
  }

  /// HTTP-based code generation
  Future<String> codeHttp(String prompt, {bool advanced = false}) async {
    try {
      final endpoint = advanced ? '/ai/advanced_code' : '/ai/code';
      final response = await http.post(
        Uri.parse('http://localhost:18789$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'options': {'advanced': advanced},
        }),
      ).timeout(const Duration(minutes: 5));

      return response.body;
    } catch (e) {
      _addLog('[ERROR] Code generation failed: $e');
      rethrow;
    }
  }

  void _updateState(AIGatewayState newState) {
    _state = newState;
    notifyListeners();
  }

  void _addLog(String log) {
    final logs = [..._state.logs, log];
    if (logs.length > 500) {
      logs.removeRange(0, logs.length - 500);
    }
    _updateState(_state.copyWith(logs: logs));
  }

  void _subscribeLogs() {
    _logSubscription?.cancel();
    _logSubscription = NativeBridge.gatewayLogStream.listen((log) {
      _addLog(log);
    });
  }

  void _startHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkHealth(),
    );
  }

  Future<void> _checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:18789/status'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ollamaRunning = data['ollama']?['running'] ?? false;
        
        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          ollamaConnected: ollamaRunning,
          startedAt: _state.startedAt ?? DateTime.now(),
        ));
      }
    } catch (e) {
      final isRunning = await NativeBridge.isGatewayRunning();
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          logs: [..._state.logs, '[WARN] Gateway process not running'],
        ));
        _healthTimer?.cancel();
      }
    }
  }

  void _connectWebSocket() {
    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:18790'),
      );

      _wsChannel!.stream.listen(
        (data) {
          final message = jsonDecode(data);
          switch (message['type']) {
            case 'chat:chunk':
            case 'code:chunk':
              _responseController.add(message['chunk']);
              break;
            case 'chat:complete':
            case 'code:complete':
              _responseController.add('[DONE]');
              break;
            case 'error':
              _addLog('[ERROR] ${message['message']}');
              break;
          }
        },
        onError: (error) {
          _addLog('[ERROR] WebSocket error: $error');
        },
        onDone: () {
          _addLog('[INFO] WebSocket disconnected');
        },
      );
    } catch (e) {
      _addLog('[ERROR] Failed to connect WebSocket: $e');
    }
  }

  Future<void> _updateRouting(AIMode mode) async {
    try {
      await http.post(
        Uri.parse('http://localhost:18789/routing'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mode': mode.name,
          'model': mode.defaultModel,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      _addLog('[WARN] Failed to update routing: $e');
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _wsChannel?.sink.close();
    _responseController.close();
    super.dispose();
  }
}