import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_config.dart';
import '../../state/app_state.dart';
import '../widgets/number_stepper.dart';
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
          NumberStepper(
            label: 'GPU Count',
            id: 'gpuCountStepper',
            value: config.gpuCount,
            min: 1,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(gpuCount: v)),
          ),
          NumberStepper(
            label: 'Min vCPU Count',
            id: 'minVcpuStepper',
            value: config.minVcpuCount,
            min: 1,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(minVcpuCount: v)),
          ),
          NumberStepper(
            label: 'Min Memory (GB)',
            id: 'minMemoryStepper',
            value: config.minMemoryInGb,
            min: 1,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(minMemoryInGb: v)),
          ),
          NumberStepper(
            label: 'Volume (GB)',
            id: 'volumeStepper',
            value: config.volumeInGb,
            min: 0,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(volumeInGb: v)),
          ),
          NumberStepper(
            label: 'Container Disk (GB)',
            id: 'containerDiskStepper',
            value: config.containerDiskInGb,
            min: 0,
            onChanged: (v) => appState.updateConfig((c) => c.copyWith(containerDiskInGb: v)),
          ),
          NumberStepper(
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
