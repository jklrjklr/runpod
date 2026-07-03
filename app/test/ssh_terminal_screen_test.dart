import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runpod_manager/data/ssh_connector.dart';
import 'package:runpod_manager/state/app_state.dart';
import 'package:runpod_manager/ui/screens/ssh_terminal_screen.dart';

import 'fake_runpod_client.dart';
import 'fake_settings_store.dart';

class FakeSshShellHandle implements SshShellHandle {
  final _outputController = StreamController<Uint8List>.broadcast();
  final List<Uint8List> written = [];
  bool closed = false;

  @override
  Stream<Uint8List> get output => _outputController.stream;

  @override
  void write(Uint8List data) => written.add(data);

  @override
  void resize(int width, int height) {}

  @override
  Future<int?> get exitCode => Completer<int?>().future;

  @override
  void close() => closed = true;

  void emit(String text) => _outputController.add(Uint8List.fromList(utf8.encode(text)));
}

class FakeSshConnector implements SshConnector {
  final FakeSshShellHandle handle;
  final Object? failWith;
  String? lastHost;
  int? lastPort;

  FakeSshConnector(this.handle, {this.failWith});

  @override
  Future<SshShellHandle> connectShell({
    required String host,
    required int port,
    required String username,
    required SSHKeyPair identity,
    int cols = 80,
    int rows = 24,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    lastHost = host;
    lastPort = port;
    if (failWith != null) throw failWith!;
    return handle;
  }
}

void main() {
  Widget buildScreen(SshConnector connector) {
    final appState = AppState(client: FakeRunPodClient(), store: FakeSettingsStore());
    return MaterialApp(
      home: ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: SshTerminalScreen(host: '10.0.0.5', port: 22022, connector: connector),
      ),
    );
  }

  testWidgets('connects, renders remote output, and forwards keystrokes to the shell',
      (tester) async {
    final handle = FakeSshShellHandle();
    final connector = FakeSshConnector(handle);

    await tester.pumpWidget(buildScreen(connector));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sshTerminalView')), findsOneWidget);
    expect(connector.lastHost, '10.0.0.5');
    expect(connector.lastPort, 22022);

    final screenState =
        tester.state(find.byType(SshTerminalScreen)) as dynamic;
    handle.emit('hello from remote shell\n');
    await tester.pump();
    expect(screenState.terminal.buffer.getText(), contains('hello from remote shell'));

    screenState.terminal.onOutput?.call('ls\n');
    await tester.pump();
    expect(handle.written, isNotEmpty);
    expect(utf8.decode(handle.written.first), 'ls\n');
  });

  testWidgets('shows an error and lets the user retry when the connection fails',
      (tester) async {
    final handle = FakeSshShellHandle();
    final connector = FakeSshConnector(handle, failWith: Exception('connection refused'));

    await tester.pumpWidget(buildScreen(connector));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sshErrorText')), findsOneWidget);
    expect(find.textContaining('connection refused'), findsOneWidget);
    expect(find.byKey(const Key('sshRetryButton')), findsOneWidget);
  });
}
