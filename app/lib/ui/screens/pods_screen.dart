import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pod.dart';
import '../../state/app_state.dart';
import 'pod_detail_screen.dart';

class PodsScreen extends StatefulWidget {
  const PodsScreen({super.key});

  @override
  State<PodsScreen> createState() => _PodsScreenState();
}

class _PodsScreenState extends State<PodsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPods();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pods'),
        actions: [
          IconButton(
            key: const Key('refreshPodsButton'),
            icon: const Icon(Icons.refresh),
            onPressed: () => appState.loadPods(),
          ),
        ],
      ),
      body: _buildBody(appState),
    );
  }

  Widget _buildBody(AppState appState) {
    if (appState.loadingPods && appState.pods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (appState.podsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load pods: ${appState.podsError}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => appState.loadPods(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (appState.pods.isEmpty) {
      return const Center(
        child: Text('No pods yet. Deploy one from the Browse tab.'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => appState.loadPods(),
      child: ListView.builder(
        itemCount: appState.pods.length,
        itemBuilder: (context, index) => _PodListTile(pod: appState.pods[index]),
      ),
    );
  }
}

class _PodListTile extends StatelessWidget {
  final Pod pod;
  const _PodListTile({required this.pod});

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RUNNING':
        return Colors.green;
      case 'EXITED':
      case 'TERMINATED':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final isRunning = pod.desiredStatus.toUpperCase() == 'RUNNING';

    return Card(
      key: Key('podListTile_${pod.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(pod.name?.isNotEmpty == true ? pod.name! : pod.id),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pod.gpuDisplayName != null)
              Text('${pod.gpuDisplayName}${pod.gpuCount != null ? ' x${pod.gpuCount}' : ''}'),
            if (pod.costPerHr != null) Text('\$${pod.costPerHr!.toStringAsFixed(3)}/hr'),
          ],
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(pod.desiredStatus).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            pod.desiredStatus.toUpperCase(),
            style: TextStyle(
              color: _statusColor(pod.desiredStatus),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: Key('podMenuButton_${pod.id}'),
          onSelected: (action) async {
            switch (action) {
              case 'stop':
                await appState.stopPod(pod.id);
                break;
              case 'resume':
                await appState.resumePod(pod.id, gpuCount: pod.gpuCount ?? 1);
                break;
              case 'terminate':
                await appState.terminatePod(pod.id);
                break;
            }
          },
          itemBuilder: (context) => [
            if (isRunning)
              const PopupMenuItem(value: 'stop', child: Text('Stop'))
            else
              const PopupMenuItem(value: 'resume', child: Text('Resume')),
            const PopupMenuItem(value: 'terminate', child: Text('Terminate')),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PodDetailScreen(podId: pod.id)),
          );
        },
      ),
    );
  }
}
