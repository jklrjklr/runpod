import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/runpod_client.dart';
import 'data/settings_store.dart';
import 'state/app_state.dart';
import 'ui/app.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        client: HttpRunPodClient(),
        store: SharedPreferencesSettingsStore(),
      ),
      child: const RunPodManagerApp(),
    ),
  );
}
