import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/device_service.dart';
import '../../engine/models/model_tier.dart';
import '../../providers/app_providers.dart';

class ModelSelectionScreen extends ConsumerStatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  ConsumerState<ModelSelectionScreen> createState() =>
      _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends ConsumerState<ModelSelectionScreen> {
  DeviceCompatibilityReport? _report;

  @override
  void initState() {
    super.initState();
    _loadCompat();
  }

  Future<void> _loadCompat() async {
    final report = await ref.read(deviceServiceProvider).getCompatibilityReport();
    if (!mounted) return;
    setState(() => _report = report);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose AI Model')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (report != null && report.totalRamGb > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Device RAM: ${report.totalRamGb.toStringAsFixed(1)} GB '
                '(${report.effectiveRamGb.toStringAsFixed(1)} GB usable after OS headroom)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final category in ModelCategory.values) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${category.label} Tier',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ...ModelTier.availableTiers
                .where((t) => t.category == category)
                .map((tier) => _buildTierCard(context, tier, report)),
          ],
        ],
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context,
    ModelTier tier,
    DeviceCompatibilityReport? report,
  ) {
    final theme = Theme.of(context);
    final enoughRam = report?.hasEnoughRam(tier.runtimeRamGb) ?? true;
    final enoughStorage =
        report?.hasEnoughStorage(tier.totalDownloadBytes) ?? true;
    final compatible = enoughRam && enoughStorage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/models/download/${tier.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tier.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (tier.isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⭐ Recommended',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tier.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _badge(context, tier.downloadSizeLabel),
                  _badge(context, '${tier.minRamGb} GB+ RAM'),
                  if (tier.supportsVision) _badge(context, 'Vision'),
                  if (tier.supportsDocumentQa) _badge(context, 'Docs Q&A'),
                ],
              ),
              if (!compatible) ...[
                const SizedBox(height: 8),
                Text(
                  !enoughRam
                      ? 'Warning: May exceed available device RAM (${tier.runtimeRamGb} GB runtime needed).'
                      : 'Warning: Not enough free storage space.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
