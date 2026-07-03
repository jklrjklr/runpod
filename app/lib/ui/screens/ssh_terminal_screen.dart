import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../../data/ssh_connector.dart';
import '../../state/app_state.dart';

class SshTerminalScreen extends StatefulWidget {
  final String host;
  final int port;
  final String username;
  final SshConnector connector;

  const SshTerminalScreen({
    super.key,
    required this.host,
    required this.port,
    this.username = 'root',
    this.connector = const DartSshConnector(),
  });

  @override
  State<SshTerminalScreen> createState() => _SshTerminalScreenState();
}

class _SshTerminalScreenState extends State<SshTerminalScreen> {
  late final Terminal terminal = Terminal(maxLines: 10000);
  SshShellHandle? _handle;
  StreamSubscription<Uint8List>? _outputSub;
  String? _error;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    terminal.onOutput = (data) {
      _handle?.write(Uint8List.fromList(utf8.encode(data)));
    };
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _handle?.resize(width, height);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _connect() async {
    try {
      final identity = await context.read<AppState>().sshKeyManager.ensureIdentity();
      final handle = await widget.connector.connectShell(
        host: widget.host,
        port: widget.port,
        username: widget.username,
        identity: identity.keyPair,
        cols: terminal.viewWidth,
        rows: terminal.viewHeight,
      );
      if (!mounted) {
        handle.close();
        return;
      }
      _handle = handle;
      _outputSub = handle.output.listen((data) {
        terminal.write(utf8.decode(data, allowMalformed: true));
      });
      setState(() => _connecting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _outputSub?.cancel();
    _handle?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SSH: ${widget.host}:${widget.port}')),
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                key: const Key('sshErrorText'),
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('sshRetryButton'),
                onPressed: () => setState(() {
                  _connecting = true;
                  _error = null;
                  _connect();
                }),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return TerminalView(
      key: const Key('sshTerminalView'),
      terminal,
      autofocus: true,
    );
  }
}
