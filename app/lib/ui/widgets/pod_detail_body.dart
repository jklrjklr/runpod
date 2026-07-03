import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/pod.dart';
import '../screens/ssh_terminal_screen.dart';

/// Status card + connection/lifecycle actions for a single pod. Shared by
/// the "just deployed" screen (sourced from AppState.currentPod) and the
/// Pods tab's detail screen (sourced from AppState.pods), which differ only
/// in where the [Pod] and action callbacks come from.
class PodDetailBody extends StatelessWidget {
  final Pod pod;
  final Future<void> Function() onStop;
  final Future<void> Function() onResume;
  final Future<void> Function() onTerminate;

  const PodDetailBody({
    super.key,
    required this.pod,
    required this.onStop,
    required this.onResume,
    required this.onTerminate,
  });

  bool get _isRunning => pod.desiredStatus.toUpperCase() == 'RUNNING';

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
    final runtime = pod.runtime;
    final proxyUrl = pod.proxyUrl();

    return ListView(
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
                if (pod.gpuDisplayName != null) ...[
                  const SizedBox(height: 8),
                  Text('GPU: ${pod.gpuDisplayName}${pod.gpuCount != null ? ' x${pod.gpuCount}' : ''}'),
                ],
                if (pod.costPerHr != null) ...[
                  const SizedBox(height: 8),
                  Text('Cost: \$${pod.costPerHr!.toStringAsFixed(3)}/hr'),
                ],
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
        else if (_isRunning)
          const Text('Waiting for an HTTP port to become available...'),
        const SizedBox(height: 12),
        if (runtime?.sshPort != null)
          FilledButton.icon(
            key: const Key('sshTerminalButton'),
            onPressed: () {
              final sshPort = runtime!.sshPort!;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SshTerminalScreen(
                    host: sshPort.ip,
                    port: sshPort.publicPort,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.terminal),
            label: const Text('SSH Terminal'),
          )
        else if (_isRunning)
          const Text('Waiting for an SSH port to become available...'),
        const SizedBox(height: 24),
        if (_isRunning)
          OutlinedButton.icon(
            key: const Key('stopPodButton'),
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop Pod'),
          )
        else
          OutlinedButton.icon(
            key: const Key('resumePodButton'),
            onPressed: onResume,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Resume Pod'),
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
            if (confirmed == true) await onTerminate();
          },
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Terminate Pod'),
        ),
      ],
    );
  }
}
