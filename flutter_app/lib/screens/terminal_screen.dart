import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
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
    _controller = TerminalController();
    NativeBridge.startTerminalService();
    _startPty();
  }

  Future<void> _startPty() async {
    try {
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config);

      _pty = Pty.start(
        config['executable']!,
        arguments: args,
        environment: TerminalService.buildHostEnv(config),
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      _pty!.output.cast<List<int>>().listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      _pty!.exitCode.then((code) {
        _terminal.write('\r\n[Process exited with code $code]\r\n');
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
        _error = 'Failed to start terminal: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pty?.kill();
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  void _copySelection() {
    final text = _terminal.selectedText;
    if (text != null && text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _pty?.write(utf8.encode(data.text!));
    }
  }

  /// Detect URLs in terminal line at tap position and open them.
  void _handleTap(TapUpDetails details, CellOffset offset) {
    // Read the line from the terminal buffer
    final line = _terminal.buffer.lines.length > offset.y
        ? _getLineText(offset.y)
        : '';
    if (line.isEmpty) return;

    // Find URLs in the line
    final urlPattern = RegExp(
      r'https?://[^\s<>\[\]"''\)]+',
      caseSensitive: false,
    );
    for (final match in urlPattern.allMatches(line)) {
      final url = match.group(0)!;
      // Check if tap x-position is within or near the URL
      if (offset.x >= match.start && offset.x <= match.end) {
        _openUrl(url);
        return;
      }
    }
  }

  String _getLineText(int row) {
    try {
      final line = _terminal.buffer.lines[row];
      final sb = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final char = line.cellGetContent(i);
        if (char != 0) {
          sb.writeCharCode(char);
        }
      }
      return sb.toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Link'),
        content: Text(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied'),
                  duration: Duration(seconds: 1),
                ),
              );
              Navigator.pop(ctx, false);
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
            onPressed: _copySelection,
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Paste',
            onPressed: _paste,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart',
            onPressed: () {
              _pty?.kill();
              setState(() {
                _loading = true;
                _error = null;
              });
              _startPty();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting terminal...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
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
                  });
                  _startPty();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: TerminalView(
            _terminal,
            controller: _controller,
            textStyle: TerminalStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              fontFamilyFallback: _fontFallback,
            ),
            onTapUp: _handleTap,
          ),
        ),
        TerminalToolbar(pty: _pty),
      ],
    );
  }
}
