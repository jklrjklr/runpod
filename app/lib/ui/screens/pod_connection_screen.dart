import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/pod_detail_body.dart';

class PodConnectionScreen extends StatelessWidget {
  const PodConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pod = appState.currentPod;

    if (pod == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pod')),
        body: const Center(child: Text('No active pod')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pod ${pod.id}'),
        actions: [
          IconButton(
            key: const Key('refreshPodButton'),
            icon: const Icon(Icons.refresh),
            onPressed: () => appState.refreshPodStatus(),
          ),
        ],
      ),
      body: PodDetailBody(
        pod: pod,
        onStop: () => appState.stopCurrentPod(),
        onResume: () => appState.resumePod(pod.id, gpuCount: pod.gpuCount ?? 1),
        onTerminate: () async {
          await appState.terminateCurrentPod();
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
