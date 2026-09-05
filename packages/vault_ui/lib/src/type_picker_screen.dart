// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'template_presentation.dart';
import 'type_picker_controller.dart';

final class TypePickerScreen extends StatefulWidget {
  const TypePickerScreen({
    required this.controller,
    required this.onTypeSelected,
    required this.onCustomType,
    super.key,
  });

  final TypePickerController controller;
  final ValueChanged<RecordTypeDefinition> onTypeSelected;
  final VoidCallback onCustomType;

  @override
  State<TypePickerScreen> createState() => _TypePickerScreenState();
}

final class _TypePickerScreenState extends State<TypePickerScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.controller.query);
  }

  @override
  void didUpdateWidget(TypePickerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _searchController.text = widget.controller.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.typePickerTitle)),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  LocalholdSpacing.md,
                  LocalholdSpacing.sm,
                  LocalholdSpacing.md,
                  LocalholdSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: _searchController,
                    onChanged: widget.controller.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: strings.typePickerSearch,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: widget.controller.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .deleteButtonTooltip,
                              onPressed: () {
                                _searchController.clear();
                                widget.controller.setQuery('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
              ),
              if (widget.controller.query.isEmpty &&
                  widget.controller.recentTemplates.isNotEmpty)
                _section(
                  strings.typePickerRecent,
                  widget.controller.recentTemplates,
                  strings,
                ),
              for (final category in TypePickerController.categoryOrder)
                if (_templates(category, strings).isNotEmpty)
                  _section(
                    localizedTemplateCategory(strings, category),
                    _templates(category, strings),
                    strings,
                  ),
              if (!_hasMatches(strings))
                SliverPadding(
                  padding: const EdgeInsets.all(LocalholdSpacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      strings.typePickerNoResults,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  LocalholdSpacing.md,
                  LocalholdSpacing.lg,
                  LocalholdSpacing.md,
                  LocalholdSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: ListTile(
                      key: const ValueKey('type_picker_custom'),
                      leading: const Icon(Icons.tune),
                      title: Text(strings.typePickerCustom),
                      subtitle: Text(strings.premiumBadge),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: widget.onCustomType,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<RecordTypeDefinition> _templates(
    TemplateCategory category,
    LocalholdLocalizations strings,
  ) => widget.controller.templatesIn(
    category,
    localizedName: (stableId) => localizedTemplateName(strings, stableId),
  );

  bool _hasMatches(LocalholdLocalizations strings) => TypePickerController
      .categoryOrder
      .any((category) => _templates(category, strings).isNotEmpty);

  SliverMainAxisGroup _section(
    String title,
    List<RecordTypeDefinition> templates,
    LocalholdLocalizations strings,
  ) => SliverMainAxisGroup(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          LocalholdSpacing.md,
          LocalholdSpacing.md,
          LocalholdSpacing.md,
          LocalholdSpacing.xs,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
      SliverList.builder(
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final template = templates[index];
          return ListTile(
            leading: Icon(templateIconData(template.icon)),
            title: Text(localizedTemplateName(strings, template.stableId)),
            onTap: () {
              widget.controller.rememberSelection(template.stableId);
              widget.onTypeSelected(template);
            },
          );
        },
      ),
    ],
  );
}
