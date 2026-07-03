import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_config.dart';
import '../../state/app_state.dart';
import 'deploying_screen.dart';

class DeployPanelScreen extends StatelessWidget {
  const DeployPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final config = appState.config;

    return Scaffold(
      appBar: AppBar(title: const Text('Deploy Panel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<CloudType>(
            key: const Key('cloudTypeDropdown'),
            initialValue: config.cloudType,
            decoration: const InputDecoration(labelText: 'Cloud Type'),
            items: CloudType.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase())))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                appState.updateConfig((c) => c.copyWith(cloudType: value));
              }
            },
          ),
          const SizedBox(height: 16),
          _Stepper(
            label: 'GPU Count',
            id: 'gpuCountStepper',
            value: config.gpuCount,
            min: 1,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(gpuCount: v)),
          ),
          _Stepper(
            label: 'Min vCPU Count',
            id: 'minVcpuStepper',
            value: config.minVcpuCount,
            min: 1,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(minVcpuCount: v)),
          ),
          _Stepper(
            label: 'Min Memory (GB)',
            id: 'minMemoryStepper',
            value: config.minMemoryInGb,
            min: 1,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(minMemoryInGb: v)),
          ),
          _Stepper(
            label: 'Volume (GB)',
            id: 'volumeStepper',
            value: config.volumeInGb,
            min: 0,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(volumeInGb: v)),
          ),
          _Stepper(
            label: 'Container Disk (GB)',
            id: 'containerDiskStepper',
            value: config.containerDiskInGb,
            min: 0,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(containerDiskInGb: v)),
          ),
          _Stepper(
            label: 'Max Retry Count',
            id: 'maxRetryStepper',
            value: config.maxRetryCount,
            min: 0,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(maxRetryCount: v)),
          ),
          const SizedBox(height: 24),
          if (config.selectedGpuTypeId == null || config.selectedTemplateId == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Select a GPU and a template on the Browse screen before deploying.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          FilledButton.icon(
            key: const Key('deployButton'),
            onPressed: (config.selectedGpuTypeId == null || config.selectedTemplateId == null)
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DeployingScreen()),
                    );
                  },
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Deploy'),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final String id;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.id,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            key: Key('${id}_decrement'),
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              key: Key(id),
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            key: Key('${id}_increment'),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}
