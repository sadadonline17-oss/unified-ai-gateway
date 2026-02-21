import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_mode.dart';
import '../providers/ai_gateway_provider.dart';

/// Models management screen for Ollama models
class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  final _modelController = TextEditingController();
  bool _isPulling = false;
  String? _pullingModel;

  final _recommendedModels = [
    {'name': 'llama3', 'description': 'Meta Llama 3 - General purpose', 'size': '~4.7 GB'},
    {'name': 'deepseek-coder', 'description': 'DeepSeek Coder - Code generation', 'size': '~1.6 GB'},
    {'name': 'qwen2.5-coder', 'description': 'Qwen 2.5 Coder - Advanced coding', 'size': '~4.7 GB'},
    {'name': 'codellama', 'description': 'Code Llama - Meta code model', 'size': '~4.7 GB'},
    {'name': 'mistral', 'description': 'Mistral - Fast and efficient', 'size': '~4.1 GB'},
    {'name': 'phi3', 'description': 'Phi-3 - Microsoft small model', 'size': '~2.2 GB'},
  ];

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AIGatewayProvider>().fetchModels(),
          ),
        ],
      ),
      body: Consumer<AIGatewayProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPullModelCard(provider),
                const SizedBox(height: 16),
                _buildRecommendedModels(provider),
                const SizedBox(height: 16),
                _buildInstalledModels(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPullModelCard(AIGatewayProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pull New Model',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      hintText: 'Model name (e.g., llama3)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    enabled: !_isPulling,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isPulling
                      ? null
                      : () => _pullModel(_modelController.text.trim(), provider),
                  icon: _isPulling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isPulling ? 'Pulling...' : 'Pull'),
                ),
              ],
            ),
            if (_pullingModel != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(
                'Pulling $_pullingModel...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedModels(AIGatewayProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended Models',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to pull a model for specific use cases',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...List.generate(_recommendedModels.length, (index) {
              final model = _recommendedModels[index];
              final isInstalled = provider.state.availableModels
                  .any((m) => m.name.contains(model['name']!));

              return ListTile(
                dense: true,
                leading: Icon(
                  isInstalled ? Icons.check_circle : Icons.download,
                  color: isInstalled ? Colors.green : null,
                ),
                title: Text(model['name']!),
                subtitle: Text(
                  '${model['description']} • ${model['size']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: isInstalled
                    ? const Text('Installed', style: TextStyle(color: Colors.green))
                    : TextButton(
                        onPressed: _isPulling
                            ? null
                            : () => _pullModel(model['name']!, provider),
                        child: const Text('Pull'),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledModels(AIGatewayProvider provider) {
    final models = provider.state.availableModels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Installed Models',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${models.length} models',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (models.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No models installed.\nPull a model from above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.inventory_2),
                    title: Text(model.name),
                    subtitle: Text(
                      'Size: ${model.sizeFormatted}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'use_chat',
                          child: Text('Use for Chat'),
                        ),
                        const PopupMenuItem(
                          value: 'use_code',
                          child: Text('Use for Code'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      onSelected: (value) => _handleModelAction(
                        value,
                        model.name,
                        provider,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pullModel(String modelName, AIGatewayProvider provider) async {
    if (modelName.isEmpty) return;

    setState(() {
      _isPulling = true;
      _pullingModel = modelName;
    });

    try {
      await provider.pullModel(modelName);
      _modelController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$modelName pulled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pull model: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPulling = false;
          _pullingModel = null;
        });
      }
    }
  }

  void _handleModelAction(String action, String modelName, AIGatewayProvider provider) {
    switch (action) {
      case 'use_chat':
        provider.setMode(AIMode.chat);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$modelName set for chat mode')),
        );
        break;
      case 'use_code':
        provider.setMode(AIMode.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$modelName set for code mode')),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(modelName);
        break;
    }
  }

  void _showDeleteConfirmation(String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete $modelName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement model deletion
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Delete not implemented yet')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}