import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../domain/entities/vehicle_catalog.dart';

/// A form field that opens a searchable sheet instead of an in-place
/// dropdown.
///
/// `DropdownButtonFormField` builds every item up front; on web that stalls
/// the first frame of the add-vehicle sheet. The sheet uses a lazy
/// `ListView.builder` and keeps search state local, so typing a filter never
/// rebuilds the form behind it. Search matches English names and Arabic
/// transliterations alike.
class VehicleCatalogField extends StatelessWidget {
  const VehicleCatalogField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.prefixIcon = Icons.directions_car_outlined,
    this.emptyHint,
  });

  final String label;

  /// English catalogue key, or [VehicleCatalog.otherKey].
  final String? value;
  final List<CatalogName> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final IconData prefixIcon;

  /// Shown when [enabled] is false — typically "pick a make first".
  final String? emptyHint;

  bool get _isOther => value == VehicleCatalog.otherKey;

  CatalogName? get _named {
    final key = value;
    if (key == null || key == VehicleCatalog.otherKey) return null;
    for (final option in options) {
      if (option.en == key) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final arabic = l10n.isArabic;
    final otherLabel = l10n.raw('otherOption');
    final named = _named;
    final display = switch (value) {
      null => emptyHint ?? '—',
      VehicleCatalog.otherKey => otherLabel,
      _ => named?.dualLabel(arabic: arabic) ?? value!,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FormField<String>(
        initialValue: value,
        validator: (_) {
          if (!enabled) return l10n.raw('selectMakeFirst');
          if (value == null || value!.isEmpty) return l10n.required_;
          return null;
        },
        builder: (state) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled
                ? () async {
                    final picked = await showVehicleCatalogPicker(
                      context: context,
                      title: label,
                      options: options,
                      selected: value,
                    );
                    if (picked == null) return;
                    onChanged(picked);
                    state.didChange(picked);
                  }
                : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '$label *',
                helperText: ' ',
                helperMaxLines: 1,
                errorText: state.errorText,
                errorMaxLines: 1,
                prefixIcon: Icon(prefixIcon, size: 20),
                suffixIcon: const Icon(Icons.expand_more_rounded),
                enabled: enabled,
              ),
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge?.copyWith(
                  color: enabled
                      ? (_isOther || value != null
                            ? context.colors.onSurface
                            : context.tokens.textSecondary)
                      : context.tokens.textSecondary,
                  fontWeight: _isOther ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<String?> showVehicleCatalogPicker({
  required BuildContext context,
  required String title,
  required List<CatalogName> options,
  required String? selected,
}) => showAppSheet<String>(
  context: context,
  builder: (_) =>
      _CatalogPickerSheet(title: title, options: options, selected: selected),
);

class _CatalogPickerSheet extends StatefulWidget {
  const _CatalogPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<CatalogName> options;
  final String? selected;

  @override
  State<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<_CatalogPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final arabic = l10n.isArabic;
    final otherLabel = l10n.raw('otherOption');
    final needle = _query.text.trim();
    final filtered = needle.isEmpty
        ? widget.options
        : [
            for (final option in widget.options)
              if (option.matches(needle)) option,
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(widget.title, style: context.text.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.raw('searchCatalog'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: needle.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.delete,
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(_query.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.raw('noCatalogMatches'),
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return _CatalogTile(
                            key: const ValueKey(VehicleCatalog.otherKey),
                            title: otherLabel,
                            selected:
                                widget.selected == VehicleCatalog.otherKey,
                            emphasized: true,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(VehicleCatalog.otherKey),
                          );
                        }
                        final option = filtered[index];
                        return _CatalogTile(
                          key: ValueKey(option.en),
                          title: option.dualLabel(arabic: arabic),
                          selected: widget.selected == option.en,
                          onTap: () => Navigator.of(context).pop(option.en),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colors.primary
        : emphasized
        ? context.colors.onSurface
        : context.tokens.textSecondary;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: context.text.titleSmall?.copyWith(
          color: color,
          fontWeight: selected || emphasized
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: context.colors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
