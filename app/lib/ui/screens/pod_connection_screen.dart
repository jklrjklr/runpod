import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';

class PodConnectionScreen extends StatelessWidget {
  const PodConnectionScreen({super.key});

  Future<void> _openInBrowser(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

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

    final runtime = pod.runtime;
    final proxyUrl = pod.proxyUrl();

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${pod.desiredStatus}',
                      key: const Key('podStatusText'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Uptime: ${runtime?.uptimeInSeconds ?? 0}s'),
                  const SizedBox(height: 8),
                  if (runtime != null && runtime.gpus.isNotEmpty)
                    ...runtime.gpus.map(
                      (g) => Text('GPU ${g.id}: ${g.gpuUtilPercent}% util, '
                          '${g.memoryUtilPercent}% mem'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (proxyUrl.isNotEmpty)
            FilledButton.icon(
              key: const Key('openInBrowserButton'),
              onPressed: () => _openInBrowser(context, proxyUrl),
              icon: const Icon(Icons.open_in_browser),
              label: Text('Open $proxyUrl'),
            )
          else
            const Text('Waiting for an HTTP port to become available...'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('stopPodButton'),
            onPressed: () async {
              await appState.stopCurrentPod();
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop Pod'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('terminatePodButton'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Terminate Pod'),
                  content: const Text(
                      'This permanently deletes the pod and its volume. This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Terminate'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await appState.terminateCurrentPod();
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Terminate Pod'),
          ),
        ],
      ),
    );
  }
}
