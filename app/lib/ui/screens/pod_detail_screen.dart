import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/pod_detail_body.dart';

/// Detail/actions view for a pod reached from the Pods tab list, as opposed
/// to [PodConnectionScreen] which is reached right after a fresh deploy.
class PodDetailScreen extends StatelessWidget {
  final String podId;

  const PodDetailScreen({super.key, required this.podId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final matches = appState.pods.where((p) => p.id == podId);
    final pod = matches.isEmpty ? null : matches.first;

    if (pod == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pod')),
        body: const Center(child: Text('This pod no longer exists')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pod ${pod.id}'),
        actions: [
          IconButton(
            key: const Key('refreshPodButton'),
            icon: const Icon(Icons.refresh),
            onPressed: () => appState.refreshPod(podId),
          ),
        ],
      ),
      body: PodDetailBody(
        pod: pod,
        onStop: () => appState.stopPod(podId),
        onResume: () => appState.resumePod(podId, gpuCount: pod.gpuCount ?? 1),
        onTerminate: () async {
          await appState.terminatePod(podId);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
