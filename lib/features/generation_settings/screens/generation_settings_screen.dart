import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/error_translator.dart';
import '../../../data/models/generation_settings.dart';
import '../../../data/models/subscription.dart';
import '../../../shared_widgets/pro_upsell_dialog.dart';
import '../../subscription/controllers/subscription_controller.dart';
import '../controllers/generation_settings_controller.dart';

class GenerationSettingsScreen extends ConsumerWidget {
  const GenerationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionControllerProvider);
    final settingsAsync = ref.watch(generationSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки генерации')),
      body: settingsAsync.when(
        data: (settings) {
          final isFree =
              subscriptionAsync.valueOrNull?.tier == SubscriptionTier.free;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Качество результата',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _PresetCard(
                title: 'Быстро',
                description: 'Меньше времени и ресурсов ИИ, результат попроще',
                icon: Icons.bolt_outlined,
                selected: settings.qualityPreset == QualityPreset.fast,
                onTap: () => ref
                    .read(generationSettingsControllerProvider.notifier)
                    .saveSettings(
                      settings.copyWith(qualityPreset: QualityPreset.fast),
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PresetCard(
                title: 'Баланс',
                description:
                    'Оптимальное соотношение качества и скорости',
                icon: Icons.tune,
                selected: settings.qualityPreset == QualityPreset.balanced,
                onTap: () => ref
                    .read(generationSettingsControllerProvider.notifier)
                    .saveSettings(
                      settings.copyWith(qualityPreset: QualityPreset.balanced),
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PresetCard(
                title: 'Максимум',
                description:
                    'Больше ресурсов ИИ ради лучшего качества',
                icon: Icons.workspace_premium_outlined,
                selected: settings.qualityPreset == QualityPreset.maximum,
                locked: isFree,
                onTap: () {
                  if (isFree) {
                    showProUpsellDialog(
                      context,
                      message:
                          'Пресет "Максимум" доступен на подписке Pro и выше.',
                    );
                    return;
                  }
                  ref
                      .read(generationSettingsControllerProvider.notifier)
                      .saveSettings(
                        settings.copyWith(qualityPreset: QualityPreset.maximum),
                      );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Реализм', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _TwoOptionToggle<RealismLevel>(
                value: settings.realism,
                options: const {
                  RealismLevel.stylized: 'Стилизованно',
                  RealismLevel.photoreal: 'Фотореалистично',
                },
                lockedValue: isFree ? RealismLevel.photoreal : null,
                onLockedTap: () => showProUpsellDialog(
                  context,
                  message: '"Фотореалистично" доступно на подписке Pro и выше.',
                ),
                onChanged: (value) => ref
                    .read(generationSettingsControllerProvider.notifier)
                    .saveSettings(settings.copyWith(realism: value)),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Сходство с фото',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _TwoOptionToggle<SimilarityLevel>(
                value: settings.similarity,
                options: const {
                  SimilarityLevel.relaxed: 'Свободнее',
                  SimilarityLevel.strict: 'Точное сходство',
                },
                lockedValue: isFree ? SimilarityLevel.strict : null,
                onLockedTap: () => showProUpsellDialog(
                  context,
                  message: '"Точное сходство" доступно на подписке Pro и выше.',
                ),
                onChanged: (value) => ref
                    .read(generationSettingsControllerProvider.notifier)
                    .saveSettings(settings.copyWith(similarity: value)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            friendlyErrorMessage(
              error,
              context: 'generation_settings',
              stackTrace: stackTrace,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _PresetCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // NOTE: this card must render at an identical size whether it is
    // selected or not - the border and trailing checkmark are always laid
    // out, just painted transparently/invisibly when inactive. This avoids
    // the tiles growing/shrinking (and jumping) on selection.
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.5)
          : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (locked) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.check_circle,
                color: selected ? colors.primary : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoOptionToggle<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final T? lockedValue;
  final VoidCallback? onLockedTap;

  const _TwoOptionToggle({
    required this.value,
    required this.options,
    required this.onChanged,
    this.lockedValue,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final entry in options.entries)
                ButtonSegment(
                  value: entry.key,
                  label: Text(entry.value),
                  icon: entry.key == lockedValue
                      ? const Icon(Icons.lock_outline, size: 14)
                      : null,
                ),
            ],
            selected: {value},
            onSelectionChanged: (selection) {
              final selected = selection.first;
              if (selected == lockedValue) {
                onLockedTap?.call();
                return;
              }
              onChanged(selected);
            },
          ),
        ),
      ],
    );
  }
}
