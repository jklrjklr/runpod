import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'pod_connection_screen.dart';

class DeployingScreen extends StatefulWidget {
  const DeployingScreen({super.key});

  @override
  State<DeployingScreen> createState() => _DeployingScreenState();
}

class _DeployingScreenState extends State<DeployingScreen> {
  bool _started = false;

  Future<void> _startDeploy() async {
    if (_started) return;
    _started = true;
    final appState = context.read<AppState>();
    await appState.deploy();
    if (!mounted) return;
    if (appState.currentPod != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PodConnectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDeploy());

    return Scaffold(
      appBar: AppBar(title: const Text('Deploying')),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          if (appState.deployError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      key: const Key('deployErrorText'),
                      appState.deployError!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('retryDeployButton'),
                      onPressed: () {
                        _started = false;
                        setState(() {});
                      },
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  key: const Key('deployAttemptText'),
                  'Attempt ${appState.deployAttempt + 1} of ${appState.deployMaxRetry + 1}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
