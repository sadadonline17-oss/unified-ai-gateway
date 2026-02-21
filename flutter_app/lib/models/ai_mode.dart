/// AI Mode configuration for model routing
enum AIMode {
  chat('Core Chat', 'llama3', 'General conversation and assistance'),
  code('Code Generate', 'deepseek-coder', 'Code generation and debugging'),
  advancedCode('Advanced Code', 'qwen2.5-coder', 'Complex code tasks and refactoring');

  final String displayName;
  final String defaultModel;
  final String description;

  const AIMode(this.displayName, this.defaultModel, this.description);
}

/// Model information from Ollama
class OllamaModel {
  final String name;
  final String modifiedAt;
  final int size;
  final String digest;
  final Map<String, dynamic> details;

  const OllamaModel({
    required this.name,
    required this.modifiedAt,
    required this.size,
    required this.digest,
    this.details = const {},
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] ?? '',
      modifiedAt: json['modified_at'] ?? '',
      size: json['size'] ?? 0,
      digest: json['digest'] ?? '',
      details: json['details'] ?? {},
    );
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Gateway status
enum GatewayStatus {
  stopped,
  starting,
  running,
  error,
}

/// AI Gateway state
class AIGatewayState {
  final GatewayStatus status;
  final String? errorMessage;
  final List<String> logs;
  final AIMode currentMode;
  final List<OllamaModel> availableModels;
  final String? dashboardUrl;
  final DateTime? startedAt;
  final bool ollamaConnected;

  const AIGatewayState({
    this.status = GatewayStatus.stopped,
    this.errorMessage,
    this.logs = const [],
    this.currentMode = AIMode.chat,
    this.availableModels = const [],
    this.dashboardUrl,
    this.startedAt,
    this.ollamaConnected = false,
  });

  AIGatewayState copyWith({
    GatewayStatus? status,
    String? errorMessage,
    List<String>? logs,
    AIMode? currentMode,
    List<OllamaModel>? availableModels,
    String? dashboardUrl,
    DateTime? startedAt,
    bool? ollamaConnected,
    bool clearError = false,
  }) {
    return AIGatewayState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      logs: logs ?? this.logs,
      currentMode: currentMode ?? this.currentMode,
      availableModels: availableModels ?? this.availableModels,
      dashboardUrl: dashboardUrl ?? this.dashboardUrl,
      startedAt: startedAt ?? this.startedAt,
      ollamaConnected: ollamaConnected ?? this.ollamaConnected,
    );
  }

  String? get uptime {
    if (startedAt == null) return null;
    final diff = DateTime.now().difference(startedAt!);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
  }
}