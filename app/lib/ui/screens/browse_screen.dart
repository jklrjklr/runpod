import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_config.dart';
import '../../models/gpu_pricing.dart';
import '../../models/gpu_type.dart';
import '../../state/app_state.dart';
import '../widgets/gpu_filter_sheet.dart';
import 'deploy_panel_screen.dart';

enum GpuSortOrder { price, name, vram }

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  GpuSortOrder _sortOrder = GpuSortOrder.price;
  bool _onlyAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBrowseData();
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GpuFilterSheet(
        sortOrder: _sortOrder,
        onlyAvailable: _onlyAvailable,
        onSortOrderChanged: (value) => setState(() => _sortOrder = value),
        onOnlyAvailableChanged: (value) => setState(() => _onlyAvailable = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse'),
          actions: [
            IconButton(
              key: const Key('filterButton'),
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterSheet,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Secure', key: Key('secureGpuTab')),
              Tab(text: 'Community', key: Key('communityGpuTab')),
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
                _GpuList(
                  appState: appState,
                  secureCloud: true,
                  sortOrder: _sortOrder,
                  onlyAvailable: _onlyAvailable,
                ),
                _GpuList(
                  appState: appState,
                  secureCloud: false,
                  sortOrder: _sortOrder,
                  onlyAvailable: _onlyAvailable,
                ),
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
  final bool secureCloud;
  final GpuSortOrder sortOrder;
  final bool onlyAvailable;

  const _GpuList({
    required this.appState,
    required this.secureCloud,
    required this.sortOrder,
    required this.onlyAvailable,
  });

  @override
  Widget build(BuildContext context) {
    var gpus = appState.gpuTypes
        .where((g) => secureCloud ? g.secureCloud : g.communityCloud)
        .toList();

    if (onlyAvailable) {
      gpus = gpus.where((g) {
        final pricing = appState.cachedPricing(g.id, secureCloud);
        return pricing != null &&
            pricing.stockStatus != StockStatus.none &&
            pricing.stockStatus != StockStatus.unknown;
      }).toList();
    }

    switch (sortOrder) {
      case GpuSortOrder.name:
        gpus.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
      case GpuSortOrder.vram:
        gpus.sort((a, b) => b.memoryInGb.compareTo(a.memoryInGb));
        break;
      case GpuSortOrder.price:
        gpus.sort((a, b) {
          final priceA = appState.cachedPricing(a.id, secureCloud)?.uninterruptablePrice ??
              appState.cachedPricing(a.id, secureCloud)?.minimumBidPrice ??
              double.infinity;
          final priceB = appState.cachedPricing(b.id, secureCloud)?.uninterruptablePrice ??
              appState.cachedPricing(b.id, secureCloud)?.minimumBidPrice ??
              double.infinity;
          return priceA.compareTo(priceB);
        });
        break;
    }

    if (gpus.isEmpty) {
      return const Center(child: Text('No GPUs match the current filters'));
    }
    return ListView.builder(
      itemCount: gpus.length,
      itemBuilder: (context, index) {
        final gpu = gpus[index];
        final selected = appState.config.selectedGpuTypeId == gpu.id &&
            appState.config.cloudType == (secureCloud ? CloudType.secure : CloudType.community);
        final pricing = appState.cachedPricing(gpu.id, secureCloud);
        return ListTile(
          key: Key('gpuTile_${secureCloud ? 'secure' : 'community'}_${gpu.id}'),
          leading: Icon(selected ? Icons.check_circle : Icons.memory,
              color: selected ? Colors.green : null),
          title: Text(gpu.displayName),
          subtitle: Text('${gpu.memoryInGb} GB'),
          trailing: _StockBadge(pricing: pricing),
          selected: selected,
          onTap: () => appState.selectGpu(gpu.id, secureCloud: secureCloud),
        );
      },
    );
  }
}

class _StockBadge extends StatelessWidget {
  final GpuPricing? pricing;
  const _StockBadge({required this.pricing});

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
    final pricing = this.pricing;
    if (pricing == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final price = pricing.uninterruptablePrice ?? pricing.minimumBidPrice;
    return Column(
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
            child: Text('\$${price.toStringAsFixed(2)}/hr', style: const TextStyle(fontSize: 11)),
          ),
      ],
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
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (template.isPublic ? Colors.blue : Colors.purple).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              template.isPublic ? 'PUBLIC' : 'MY TEMPLATE',
              style: TextStyle(
                color: template.isPublic ? Colors.blue : Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          selected: selected,
          onTap: () => appState.selectTemplate(template.id),
        );
      },
    );
  }
}
