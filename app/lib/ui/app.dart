import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'screens/api_key_screen.dart';
import 'screens/browse_screen.dart';

class RunPodManagerApp extends StatefulWidget {
  const RunPodManagerApp({super.key});

  @override
  State<RunPodManagerApp> createState() => _RunPodManagerAppState();
}

class _RunPodManagerAppState extends State<RunPodManagerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunPod Manager',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, _) {
          if (!appState.initialized) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return appState.hasApiKey ? const BrowseScreen() : const ApiKeyScreen();
        },
      ),
    );
  }
}
