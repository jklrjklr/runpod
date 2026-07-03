import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../screens/browse_screen.dart';
import 'number_stepper.dart';

class GpuFilterSheet extends StatelessWidget {
  final GpuSortOrder sortOrder;
  final bool onlyAvailable;
  final ValueChanged<GpuSortOrder> onSortOrderChanged;
  final ValueChanged<bool> onOnlyAvailableChanged;

  const GpuFilterSheet({
    super.key,
    required this.sortOrder,
    required this.onlyAvailable,
    required this.onSortOrderChanged,
    required this.onOnlyAvailableChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final config = appState.config;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filter & Sort', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Order by', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<GpuSortOrder>(
                key: const Key('sortOrderSegmentedButton'),
                segments: const [
                  ButtonSegment(value: GpuSortOrder.price, label: Text('Price')),
                  ButtonSegment(value: GpuSortOrder.name, label: Text('Name')),
                  ButtonSegment(value: GpuSortOrder.vram, label: Text('VRAM')),
                ],
                selected: {sortOrder},
                onSelectionChanged: (selection) => onSortOrderChanged(selection.first),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                key: const Key('onlyAvailableSwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show only available'),
                subtitle: const Text('Hide GPUs with no current stock'),
                value: onlyAvailable,
                onChanged: onOnlyAvailableChanged,
              ),
              const Divider(height: 32),
              Text('Deploy Requirements', style: Theme.of(context).textTheme.labelLarge),
              NumberStepper(
                label: 'Max Retry Count',
                id: 'filterMaxRetryStepper',
                value: config.maxRetryCount,
                min: 0,
                onChanged: (v) => appState.updateConfig((c) => c.copyWith(maxRetryCount: v)),
              ),
              NumberStepper(
                label: 'Min System Memory (GB)',
                id: 'filterMinMemoryStepper',
                value: config.minMemoryInGb,
                min: 1,
                onChanged: (v) => appState.updateConfig((c) => c.copyWith(minMemoryInGb: v)),
              ),
              NumberStepper(
                label: 'Min vCPU',
                id: 'filterMinVcpuStepper',
                value: config.minVcpuCount,
                min: 1,
                onChanged: (v) => appState.updateConfig((c) => c.copyWith(minVcpuCount: v)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('closeFilterSheetButton'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
