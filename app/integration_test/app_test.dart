import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:runpod_manager/state/app_state.dart';
import 'package:runpod_manager/ui/app.dart';

import '../test/fake_runpod_client.dart';
import '../test/fake_settings_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp(AppState appState) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const RunPodManagerApp(),
    );
  }

  testWidgets('an invalid API key is rejected with an inline error', (tester) async {
    final appState = AppState(client: FakeRunPodClient(), store: FakeSettingsStore());

    await tester.pumpWidget(buildApp(appState));
    await tester.pumpAndSettle();

    expect(find.text('RunPod Manager'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('apiKeyField')), 'wrong-key');
    await tester.tap(find.byKey(const Key('validateApiKeyButton')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid API key. Please check and try again.'), findsOneWidget);
    expect(find.text('Browse'), findsNothing);
  });

  testWidgets('full user journey: api key -> browse -> deploy -> pod connection -> stop',
      (tester) async {
    final client = FakeRunPodClient();
    final appState = AppState(
      client: client,
      store: FakeSettingsStore(),
      retryBackoff: (_) => Duration.zero,
    );

    await tester.pumpWidget(buildApp(appState));
    await tester.pumpAndSettle();

    // 1. API key screen: submit a valid key.
    await tester.enterText(find.byKey(const Key('apiKeyField')), 'test-api-key');
    await tester.tap(find.byKey(const Key('validateApiKeyButton')));
    await tester.pumpAndSettle();

    // 2. Browse screen: select a GPU (Secure tab, shown by default) and a template.
    expect(find.text('Browse'), findsOneWidget);
    expect(find.byKey(const Key('gpuTile_secure_NVIDIA H100 80GB HBM3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gpuTile_secure_NVIDIA H100 80GB HBM3')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('templateTab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('templateTile_tmpl-pytorch')));
    await tester.pumpAndSettle();

    // 3. Continue to the deploy panel.
    await tester.tap(find.byKey(const Key('continueToDeployButton')));
    await tester.pumpAndSettle();
    expect(find.text('Deploy Panel'), findsOneWidget);

    // Persistent settings: bump GPU count, which must not clear the GPU/template
    // selection made in the previous screen.
    await tester.tap(find.byKey(const Key('gpuCountStepper_increment')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('gpuCountStepper'))).controller!.text,
      '2',
    );

    // 4. Deploy.
    await tester.tap(find.byKey(const Key('deployButton')));
    await tester.pumpAndSettle();

    // 5. Pod connection screen shows the running pod and lets us stop it.
    expect(find.textContaining('Pod pod-123'), findsOneWidget);
    expect(find.text('Status: RUNNING'), findsOneWidget);
    expect(find.byKey(const Key('openInBrowserButton')), findsOneWidget);
    expect(client.deployCallCount, 1);
    expect(client.lastDeployEnv, isNotNull);
    expect(client.lastDeployEnv!['PUBLIC_KEY'], startsWith('ssh-ed25519 '));

    await tester.tap(find.byKey(const Key('stopPodButton')));
    await tester.pumpAndSettle();
    expect(find.text('Status: EXITED'), findsOneWidget);
  });

  testWidgets('deploy retries past a null-id response before succeeding', (tester) async {
    final client = FakeRunPodClient(deployNullResponsesBeforeSuccess: 2);
    final appState = AppState(
      client: client,
      store: FakeSettingsStore(),
      retryBackoff: (_) => Duration.zero,
    );

    await tester.pumpWidget(buildApp(appState));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('apiKeyField')), 'test-api-key');
    await tester.tap(find.byKey(const Key('validateApiKeyButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('communityGpuTab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gpuTile_community_NVIDIA RTX 4090')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('templateTab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('templateTile_tmpl-tensorflow')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('continueToDeployButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deployButton')));
    await tester.pumpAndSettle();

    expect(find.text('Status: RUNNING'), findsOneWidget);
    expect(client.deployCallCount, 3);
  });
}
