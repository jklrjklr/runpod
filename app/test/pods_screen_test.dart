import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runpod_manager/models/pod.dart';
import 'package:runpod_manager/state/app_state.dart';
import 'package:runpod_manager/ui/screens/pods_screen.dart';

import 'fake_runpod_client.dart';
import 'fake_settings_store.dart';

const _runningPod = Pod(
  id: 'pod-running',
  name: 'my-running-pod',
  desiredStatus: 'RUNNING',
  gpuDisplayName: 'RTX 4090',
  gpuCount: 1,
  costPerHr: 0.7,
  runtime: PodRuntime(
    uptimeInSeconds: 120,
    ports: [
      PodPort(ip: '1.2.3.4', publicPort: 8888, privatePort: 8888, type: 'http'),
      PodPort(ip: '1.2.3.4', publicPort: 22022, privatePort: 22, type: 'tcp'),
    ],
    gpus: [PodGpuUtil(id: 'gpu-0', gpuUtilPercent: 50, memoryUtilPercent: 40)],
  ),
);

const _exitedPod = Pod(
  id: 'pod-exited',
  desiredStatus: 'EXITED',
  gpuDisplayName: 'H100 80GB HBM3',
  gpuCount: 1,
  costPerHr: 2.9,
);

Future<AppState> pumpPodsScreen(WidgetTester tester, {List<Pod> initialPods = const []}) async {
  final appState = AppState(
    client: FakeRunPodClient(initialPods: initialPods),
    store: FakeSettingsStore(),
  )..apiKey = 'test-api-key';
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(home: const PodsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return appState;
}

void main() {
  testWidgets('shows an empty state when there are no pods', (tester) async {
    await pumpPodsScreen(tester);
    expect(find.text('No pods yet. Deploy one from the Browse tab.'), findsOneWidget);
  });

  testWidgets('lists pods with status badges', (tester) async {
    await pumpPodsScreen(tester, initialPods: const [_runningPod, _exitedPod]);

    expect(find.byKey(const Key('podListTile_pod-running')), findsOneWidget);
    expect(find.byKey(const Key('podListTile_pod-exited')), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('EXITED'), findsOneWidget);
  });

  testWidgets('stopping a running pod via the menu updates its status', (tester) async {
    await pumpPodsScreen(tester, initialPods: const [_runningPod]);

    await tester.tap(find.byKey(const Key('podMenuButton_pod-running')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(find.text('EXITED'), findsOneWidget);
    expect(find.text('RUNNING'), findsNothing);
  });

  testWidgets('tapping a pod opens the detail screen with working actions', (tester) async {
    await pumpPodsScreen(tester, initialPods: const [_runningPod]);

    await tester.tap(find.byKey(const Key('podListTile_pod-running')));
    await tester.pumpAndSettle();

    expect(find.text('Status: RUNNING'), findsOneWidget);
    expect(find.byKey(const Key('sshTerminalButton')), findsOneWidget);
    expect(find.byKey(const Key('openInBrowserButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stopPodButton')));
    await tester.pumpAndSettle();
    expect(find.text('Status: EXITED'), findsOneWidget);
    expect(find.byKey(const Key('resumePodButton')), findsOneWidget);
  });

  testWidgets('terminating a pod from the detail screen pops back and removes it from the list',
      (tester) async {
    await pumpPodsScreen(tester, initialPods: const [_runningPod]);

    await tester.tap(find.byKey(const Key('podListTile_pod-running')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('terminatePodButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminate'));
    await tester.pumpAndSettle();

    // Popped back to the list, and the terminated pod is gone.
    expect(find.byKey(const Key('podListTile_pod-running')), findsNothing);
    expect(find.text('No pods yet. Deploy one from the Browse tab.'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when loading pods fails', (tester) async {
    final client = FakeRunPodClient();
    final appState = AppState(client: client, store: FakeSettingsStore())
      ..apiKey = null; // apiKey! null-check inside loadPods throws, surfaced as podsError
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: const PodsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load pods'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
