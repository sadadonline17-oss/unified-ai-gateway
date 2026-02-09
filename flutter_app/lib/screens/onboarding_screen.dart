import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../services/terminal_service.dart';
import '../services/preferences_service.dart';
import '../widgets/terminal_toolbar.dart';
import 'dashboard_screen.dart';

/// Runs `openclaw onboard` in a terminal so the user can configure
/// API keys and select loopback binding. Shown after first-time setup
/// and accessible from the dashboard for re-configuration.
class OnboardingScreen extends StatefulWidget {
  /// If true, shows a "Go to Dashboard" button when onboarding exits.
  /// Used after first-time setup. If false, just pops back.
  final bool isFirstRun;

  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final Terminal _terminal;
  Pty? _pty;
  bool _loading = true;
  bool _finished = false;
  String? _error;

  static const _fontFallback = [
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'Noto Sans Mono',
    'sans-serif',
  ];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _startOnboarding();
  }

  Future<void> _startOnboarding() async {
    try {
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config);

      // Replace the login shell with a command that runs onboarding.
      // buildProotArgs ends with [..., '/bin/bash', '-l']
      // Replace with [..., '/bin/bash', '-lc', 'openclaw onboard']
      final onboardingArgs = List<String>.from(args);
      onboardingArgs.removeLast(); // remove '-l'
      onboardingArgs.removeLast(); // remove '/bin/bash'
      onboardingArgs.addAll([
        '/bin/bash', '-lc',
        'echo "=== OpenClaw Onboarding ===" && '
        'echo "Configure your API keys and binding settings." && '
        'echo "TIP: Select Loopback (127.0.0.1) when asked for binding!" && '
        'echo "" && '
        'openclaw onboard; '
        'echo "" && echo "Onboarding complete! You can close this screen."',
      ]);

      _pty = Pty.start(
        config['executable']!,
        arguments: onboardingArgs,
        // Host-side env: only proot-specific vars.
        // Guest env is set via env -i in buildProotArgs.
        environment: TerminalService.buildHostEnv(config),
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      _pty!.output.cast<List<int>>().listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      _pty!.exitCode.then((code) {
        _terminal.write('\r\n[Onboarding exited with code $code]\r\n');
        if (mounted) {
          setState(() => _finished = true);
        }
      });

      _terminal.onOutput = (data) {
        _pty?.write(utf8.encode(data));
      };

      _terminal.onResize = (w, h, pw, ph) {
        _pty?.resize(h, w);
      };

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to start onboarding: $e';
      });
    }
  }

  @override
  void dispose() {
    _pty?.kill();
    super.dispose();
  }

  Future<void> _goToDashboard() async {
    final navigator = Navigator.of(context);
    final prefs = PreferencesService();
    await prefs.init();
    prefs.setupComplete = true;
    prefs.isFirstRun = false;

    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenClaw Onboarding'),
        leading: widget.isFirstRun
            ? null // no back button during first-run
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if (_loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting onboarding...'),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                            _finished = false;
                          });
                          _startOnboarding();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Expanded(
              child: TerminalView(
                _terminal,
                textStyle: TerminalStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  fontFamilyFallback: _fontFallback,
                ),
              ),
            ),
            TerminalToolbar(pty: _pty),
          ],
          if (_finished)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.isFirstRun
                      ? _goToDashboard
                      : () => Navigator.of(context).pop(),
                  icon: Icon(widget.isFirstRun
                      ? Icons.arrow_forward
                      : Icons.check),
                  label: Text(widget.isFirstRun
                      ? 'Go to Dashboard'
                      : 'Done'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
