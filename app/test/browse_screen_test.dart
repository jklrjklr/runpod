import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runpod_manager/state/app_state.dart';
import 'package:runpod_manager/ui/screens/browse_screen.dart';

import 'fake_runpod_client.dart';
import 'fake_settings_store.dart';

void main() {
  Future<AppState> pumpBrowseScreen(WidgetTester tester) async {
    final appState = AppState(client: FakeRunPodClient(), store: FakeSettingsStore())
      ..apiKey = 'test-api-key';
    // Provider must wrap MaterialApp (not the reverse): showModalBottomSheet
    // inserts into the Navigator's Overlay, which sits above `home` in the
    // element tree, so a Provider scoped only to `home` wouldn't be visible
    // to the filter sheet.
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: const BrowseScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return appState;
  }

  testWidgets('Secure tab only shows GPUs offered on secure cloud', (tester) async {
    await pumpBrowseScreen(tester);

    // H100 is secure-only; RTX 3070 is community-only.
    expect(find.byKey(const Key('gpuTile_secure_NVIDIA H100 80GB HBM3')), findsOneWidget);
    expect(find.byKey(const Key('gpuTile_secure_NVIDIA RTX 4090')), findsOneWidget);
    expect(find.byKey(const Key('gpuTile_secure_NVIDIA RTX 3070')), findsNothing);
  });

  testWidgets('Community tab only shows GPUs offered on community cloud', (tester) async {
    await pumpBrowseScreen(tester);

    await tester.tap(find.byKey(const Key('communityGpuTab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gpuTile_community_NVIDIA H100 80GB HBM3')), findsNothing);
    expect(find.byKey(const Key('gpuTile_community_NVIDIA RTX 4090')), findsOneWidget);
    expect(find.byKey(const Key('gpuTile_community_NVIDIA RTX 3070')), findsOneWidget);
  });

  testWidgets('sorting by price orders the cheapest secure GPU first', (tester) async {
    await pumpBrowseScreen(tester);

    await tester.tap(find.byKey(const Key('filterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('closeFilterSheetButton')));
    await tester.pumpAndSettle();

    // Secure tab has H100 ($2.90/hr) and RTX 4090 ($0.70/hr) -- price order
    // should put RTX 4090 above H100.
    final rtxOffset = tester.getTopLeft(find.byKey(const Key('gpuTile_secure_NVIDIA RTX 4090')));
    final h100Offset = tester.getTopLeft(find.byKey(const Key('gpuTile_secure_NVIDIA H100 80GB HBM3')));
    expect(rtxOffset.dy, lessThan(h100Offset.dy));
  });

  testWidgets('show only available hides out-of-stock GPUs', (tester) async {
    await pumpBrowseScreen(tester);

    await tester.tap(find.byKey(const Key('communityGpuTab')));
    await tester.pumpAndSettle();
    // RTX 4090 is StockStatus.none on community in the fake backend.
    expect(find.byKey(const Key('gpuTile_community_NVIDIA RTX 4090')), findsOneWidget);

    await tester.tap(find.byKey(const Key('filterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onlyAvailableSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('closeFilterSheetButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gpuTile_community_NVIDIA RTX 4090')), findsNothing);
    expect(find.byKey(const Key('gpuTile_community_NVIDIA RTX 3070')), findsOneWidget);
  });

  testWidgets('filter sheet edits persist to deploy config', (tester) async {
    final appState = await pumpBrowseScreen(tester);

    await tester.tap(find.byKey(const Key('filterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filterMaxRetryStepper_increment')));
    await tester.pumpAndSettle();

    expect(appState.config.maxRetryCount, 4);
  });

  testWidgets('templates tab shows both public and private templates', (tester) async {
    await pumpBrowseScreen(tester);

    await tester.tap(find.byKey(const Key('templateTab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('templateTile_tmpl-pytorch')), findsOneWidget);
    expect(find.byKey(const Key('templateTile_tmpl-my-custom')), findsOneWidget);
    expect(find.text('PUBLIC'), findsWidgets);
    expect(find.text('MY TEMPLATE'), findsOneWidget);
  });
}
