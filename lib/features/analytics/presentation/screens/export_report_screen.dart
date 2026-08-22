import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/file_saver.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/analytics_report.dart';
import '../../domain/repositories/report_exporter.dart';
import '../providers/report_providers.dart';

class ExportReportScreen extends ConsumerStatefulWidget {
  const ExportReportScreen({super.key});

  @override
  ConsumerState<ExportReportScreen> createState() =>
      _ExportReportScreenState();
}

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  ReportFormat _format = ReportFormat.csv;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = ref.watch(analyticsReportProvider);
    final exportState = ref.watch(exportControllerProvider);

    ref.listen<AsyncValue<SavedFile?>>(exportControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        data: (file) {
          if (file == null) return;
          showAppSnack(
            context,
            file.downloaded
                ? '${l10n.raw('exportDownloaded')} · ${file.fileName}'
                : '${l10n.raw('exportSavedTo')} ${file.path}',
            icon: Icons.download_done_rounded,
          );
        },
        error: (_, __) =>
            showAppSnack(context, l10n.raw('exportFailed'), icon: Icons.error_outline_rounded),
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.raw('exportReport'))),
      body: report == null
          ? AppEmptyState(
              icon: Icons.description_outlined,
              title: l10n.raw('notEnoughData'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: context.screenPadding(),
                  children: [
                    _ReportSummaryCard(report: report),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: l10n.raw('exportFormat'),
                      icon: Icons.insert_drive_file_outlined,
                    ),
                    Row(
                      children: [
                        for (final format in ReportFormat.values) ...[
                          PillChip(
                            label: format.extension.toUpperCase(),
                            icon: Icons.description_outlined,
                            selected: _format == format,
                            onTap: () => setState(() => _format = format),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: exportState.isLoading
                          ? null
                          : () => ref
                                .read(exportControllerProvider.notifier)
                                .export(_format),
                      icon: exportState.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(l10n.raw('exportNow')),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppPlatform.supportsFileSystem
                          ? l10n.raw('exportSavedTo')
                          : l10n.raw('exportDownloaded'),
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ReportSummaryCard extends ConsumerWidget {
  const _ReportSummaryCard({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    return GlassCard(
      accent: AppColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.vehicleName, style: context.text.titleMedium),
          const SizedBox(height: 2),
          Text(
            report.vehicleSubtitle,
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _Row(
            label: l10n.raw('dateRange'),
            value:
                '${Fmt.date(report.rangeStart, locale)} — '
                '${Fmt.date(report.rangeEnd, locale)}',
          ),
          _Row(
            label: l10n.currentOdometer,
            value: '${Fmt.int0(report.currentOdometer, locale)} ${l10n.km}',
          ),
          _Row(
            label: l10n.raw('entries'),
            value: Fmt.int0(report.rows.length, locale),
          ),
          Divider(color: context.tokens.border, height: 24),
          _Row(
            label: l10n.tabFuel,
            value: '${Fmt.money(report.fuelCost, locale)} ${l10n.currency}',
          ),
          _Row(
            label: l10n.maintenance,
            value: '${Fmt.money(report.serviceCost, locale)} ${l10n.currency}',
          ),
          _Row(
            label: l10n.expenses,
            value: '${Fmt.money(report.otherCost, locale)} ${l10n.currency}',
          ),
          Divider(color: context.tokens.border, height: 24),
          Row(
            children: [
              Expanded(
                child: Text(l10n.totalSpend, style: context.text.titleSmall),
              ),
              StatValue(
                value: Fmt.money(report.totalCost, locale),
                unit: l10n.currency,
                color: AppColors.cyan,
                style: context.text.titleMedium,
                animate: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
          Text(value, style: context.text.labelMedium),
        ],
      ),
    );
  }
}
