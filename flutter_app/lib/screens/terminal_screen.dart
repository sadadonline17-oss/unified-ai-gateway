import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
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
  final List<String> _detectedUrls = [];
  String _outputBuffer = '';
  static final _anyUrlRegex = RegExp(r'https?://[^\s<>\[\]"' "'" r'\)]+');
  static final _ansiEscape = AppConstants.ansiEscape;

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
        final text = utf8.decode(data, allowMalformed: true);
        _terminal.write(text);
        // Detect URLs from output
        _outputBuffer += text;
        if (_outputBuffer.length > 4096) {
          _outputBuffer = _outputBuffer.substring(_outputBuffer.length - 2048);
        }
        final cleanForUrl = _outputBuffer
            .replaceAll(_ansiEscape, '')
            .replaceAll(RegExp(r'\s+'), '');
        bool urlsChanged = false;
        for (final m in _anyUrlRegex.allMatches(cleanForUrl)) {
          final url = m.group(0)!;
          if (!_detectedUrls.contains(url)) {
            _detectedUrls.add(url);
            urlsChanged = true;
            NativeBridge.showUrlNotification(url, title: 'OpenClaw URL');
          }
        }
        if (urlsChanged && mounted) {
          setState(() {});
        }
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
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return;

    final range = selection.normalized;
    final sb = StringBuffer();
    for (int y = range.begin.y; y <= range.end.y; y++) {
      if (y >= _terminal.buffer.lines.length) break;
      final line = _terminal.buffer.lines[y];
      final from = (y == range.begin.y) ? range.begin.x : 0;
      final to = (y == range.end.y) ? range.end.x : null;
      sb.write(line.getText(from, to));
      if (y < range.end.y) sb.writeln();
    }

    final text = sb.toString();
    if (text.isNotEmpty) {
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

  /// Detect URLs in terminal at tap position. Joins adjacent lines
  /// to handle URLs that wrap across terminal line boundaries.
  void _handleTap(TapUpDetails details, CellOffset offset) {
    final totalLines = _terminal.buffer.lines.length;
    final startRow = (offset.y - 2).clamp(0, totalLines - 1);
    final endRow = (offset.y + 2).clamp(0, totalLines - 1);

    final sb = StringBuffer();
    int tapOffset = 0;
    for (int row = startRow; row <= endRow; row++) {
      final lineText = _getLineText(row);
      if (row == offset.y) {
        tapOffset = sb.length + offset.x;
      }
      sb.write(lineText.trimRight());
    }
    final combined = sb.toString();
    if (combined.isEmpty) return;

    final urlPattern = RegExp(
      r'https?://[^\s<>\[\]"' "'" r'\)]+',
      caseSensitive: false,
    );
    for (final match in urlPattern.allMatches(combined)) {
      if (tapOffset >= match.start && tapOffset <= match.end) {
        _openUrl(match.group(0)!);
        return;
      }
    }
    // Fallback: if tap didn't land precisely inside a URL, check if any
    // URL overlaps the tapped line region in the combined text.
    final tappedLine = _getLineText(offset.y).trimRight();
    final lineStart = combined.indexOf(tappedLine);
    if (lineStart >= 0) {
      final lineEnd = lineStart + tappedLine.length;
      for (final match in urlPattern.allMatches(combined)) {
        if (match.start < lineEnd && match.end > lineStart) {
          _openUrl(match.group(0)!);
          return;
        }
      }
    }
  }

  String _getLineText(int row) {
    try {
      final line = _terminal.buffer.lines[row];
      final sb = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final char = line.getCodePoint(i);
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
        if (_detectedUrls.isNotEmpty)
          _buildUrlBanner(context),
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

  Widget _buildUrlBanner(BuildContext context) {
    final lastUrl = _detectedUrls.last;
    final count = _detectedUrls.length;
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.link, size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: count > 1 ? () => _showAllUrls(context) : null,
                child: Text(
                  count > 1 ? '$count URLs detected (tap to see all)' : 'URL detected',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    decoration: count > 1 ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: lastUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
            TextButton.icon(
              onPressed: () {
                final uri = Uri.tryParse(lastUrl);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllUrls(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Detected URLs',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...List.generate(_detectedUrls.length, (i) {
              final url = _detectedUrls[_detectedUrls.length - 1 - i];
              return ListTile(
                leading: const Icon(Icons.link, size: 20),
                title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      tooltip: 'Open',
                      onPressed: () {
                        Navigator.pop(ctx);
                        final uri = Uri.tryParse(url);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
