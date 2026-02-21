import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_mode.dart';
import '../providers/ai_gateway_provider.dart';
import 'terminal_screen.dart';
import 'logs_screen.dart';
import 'models_screen.dart';
import 'settings_screen.dart';

/// Main AI Dashboard with mode switching and gateway controls
class AIDashboardScreen extends StatelessWidget {
  const AIDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified AI Gateway'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Consumer<AIGatewayProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(provider),
                const SizedBox(height: 16),
                _buildModeSelector(provider),
                const SizedBox(height: 16),
                _buildQuickActions(context, provider),
                const SizedBox(height: 16),
                _buildModelStatus(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.smart_toy, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Unified AI Gateway',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                Text(
                  'Ollama + OpenClaw + NullClaw',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Terminal'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TerminalScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Models'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Logs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AIGatewayProvider provider) {
    final state = provider.state;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (state.status) {
      case GatewayStatus.running:
        statusColor = Colors.green;
        statusText = 'Running';
        statusIcon = Icons.check_circle;
        break;
      case GatewayStatus.starting:
        statusColor = Colors.orange;
        statusText = 'Starting...';
        statusIcon = Icons.pending;
        break;
      case GatewayStatus.error:
        statusColor = Colors.red;
        statusText = 'Error';
        statusIcon = Icons.error;
        break;
      case GatewayStatus.stopped:
        statusColor = Colors.grey;
        statusText = 'Stopped';
        statusIcon = Icons.stop_circle;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gateway Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (state.uptime != null)
                  Chip(
                    label: Text(state.uptime!),
                    avatar: const Icon(Icons.timer, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.status == GatewayStatus.stopped ||
                            state.status == GatewayStatus.error
                        ? provider.start
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.status == GatewayStatus.running
                        ? provider.stop
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(AIGatewayProvider provider) {
    final state = provider.state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Mode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<AIMode>(
              segments: AIMode.values.map((mode) {
                return ButtonSegment(
                  value: mode,
                  label: Text(mode.displayName),
                  icon: _getModeIcon(mode),
                );
              }).toList(),
              selected: {state.currentMode},
              onSelectionChanged: (modes) {
                provider.setMode(modes.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              state.currentMode.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Model: ${state.currentMode.defaultModel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.deepPurple,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getModeIcon(AIMode mode) {
    switch (mode) {
      case AIMode.chat:
        return const Icon(Icons.chat);
      case AIMode.code:
        return const Icon(Icons.code);
      case AIMode.advancedCode:
        return const Icon(Icons.auto_awesome);
    }
  }

  Widget _buildQuickActions(BuildContext context, AIGatewayProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.terminal),
                  label: const Text('Terminal'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TerminalScreen()),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.inventory_2),
                  label: const Text('Models'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ModelsScreen()),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.article),
                  label: const Text('Logs'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogsScreen()),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.refresh),
                  label: const Text('Refresh Models'),
                  onPressed: provider.fetchModels,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatus(AIGatewayProvider provider) {
    final state = provider.state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ollama Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(
                  state.ollamaConnected ? Icons.check_circle : Icons.error,
                  color: state.ollamaConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  state.ollamaConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: state.ollamaConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.availableModels.isEmpty)
              const Text('No models loaded. Pull models from the Models screen.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.availableModels.length} models available',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: state.availableModels.take(5).map((model) {
                      return Chip(
                        label: Text(model.name),
                        labelStyle: const TextStyle(fontSize: 12),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  if (state.availableModels.length > 5)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModelsScreen()),
                      ),
                      child: Text(
                        '+${state.availableModels.length - 5} more',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}