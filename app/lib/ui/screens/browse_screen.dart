import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/gpu_pricing.dart';
import '../../models/gpu_type.dart';
import '../../state/app_state.dart';
import 'deploy_panel_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBrowseData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'GPUs', key: Key('gpuTab')),
              Tab(text: 'Templates', key: Key('templateTab')),
            ],
          ),
        ),
        body: Consumer<AppState>(
          builder: (context, appState, _) {
            if (appState.loadingBrowseData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (appState.browseError != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load: ${appState.browseError}'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => appState.loadBrowseData(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return TabBarView(
              children: [
                _GpuList(appState: appState),
                _TemplateList(appState: appState),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('continueToDeployButton'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DeployPanelScreen()),
            );
          },
          label: const Text('Deploy Panel'),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
    );
  }
}

class _GpuList extends StatelessWidget {
  final AppState appState;
  const _GpuList({required this.appState});

  @override
  Widget build(BuildContext context) {
    if (appState.gpuTypes.isEmpty) {
      return const Center(child: Text('No GPU types available'));
    }
    return ListView.builder(
      itemCount: appState.gpuTypes.length,
      itemBuilder: (context, index) {
        final gpu = appState.gpuTypes[index];
        final selected = appState.config.selectedGpuTypeId == gpu.id;
        return ListTile(
          key: Key('gpuTile_${gpu.id}'),
          leading: Icon(selected ? Icons.check_circle : Icons.memory,
              color: selected ? Colors.green : null),
          title: Text(gpu.displayName),
          subtitle: Text('${gpu.memoryInGb} GB'
              '${gpu.secureCloud ? ' • Secure' : ''}'
              '${gpu.communityCloud ? ' • Community' : ''}'),
          trailing: _StockBadge(appState: appState, gpu: gpu),
          selected: selected,
          onTap: () => appState.selectGpu(gpu.id),
        );
      },
    );
  }
}

class _StockBadge extends StatelessWidget {
  final AppState appState;
  final GpuType gpu;
  const _StockBadge({required this.appState, required this.gpu});

  Color _colorFor(StockStatus status) {
    switch (status) {
      case StockStatus.high:
        return Colors.green;
      case StockStatus.medium:
        return Colors.lightGreen;
      case StockStatus.low:
        return Colors.orange;
      case StockStatus.none:
        return Colors.red;
      case StockStatus.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GpuPricing>(
      future: appState.getGpuPricing(gpu),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final pricing = snapshot.data!;
        final price = pricing.uninterruptablePrice ?? pricing.minimumBidPrice;
        return Column(
          key: Key('stockBadge_${gpu.id}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _colorFor(pricing.stockStatus).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pricing.stockStatus.name.toUpperCase(),
                style: TextStyle(
                  color: _colorFor(pricing.stockStatus),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            if (price != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('\$${price.toStringAsFixed(2)}/hr',
                    style: const TextStyle(fontSize: 11)),
              ),
          ],
        );
      },
    );
  }
}

class _TemplateList extends StatelessWidget {
  final AppState appState;
  const _TemplateList({required this.appState});

  @override
  Widget build(BuildContext context) {
    if (appState.templates.isEmpty) {
      return const Center(child: Text('No templates available'));
    }
    return ListView.builder(
      itemCount: appState.templates.length,
      itemBuilder: (context, index) {
        final template = appState.templates[index];
        final selected = appState.config.selectedTemplateId == template.id;
        return ListTile(
          key: Key('templateTile_${template.id}'),
          leading: Icon(selected ? Icons.check_circle : Icons.dashboard_customize,
              color: selected ? Colors.green : null),
          title: Text(template.name),
          subtitle: Text(template.imageName),
          selected: selected,
          onTap: () => appState.selectTemplate(template.id),
        );
      },
    );
  }
}
