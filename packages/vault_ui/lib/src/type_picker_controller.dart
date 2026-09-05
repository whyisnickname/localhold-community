// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

final class TypePickerController extends ChangeNotifier {
  TypePickerController({
    Iterable<RecordTypeDefinition>? templates,
    Iterable<String> recentTypeIds = const [],
  }) : templates = List.unmodifiable(templates ?? BuiltInTemplateCatalog.all),
       _recentTypeIds = _sanitizeRecents(
         recentTypeIds,
         templates ?? BuiltInTemplateCatalog.all,
       );

  static const categoryOrder = [
    TemplateCategory.accounts,
    TemplateCategory.money,
    TemplateCategory.personal,
    TemplateCategory.technical,
  ];

  static const maximumRecentTypes = 4;

  final List<RecordTypeDefinition> templates;
  List<String> _recentTypeIds;
  String _query = '';

  String get query => _query;

  List<RecordTypeDefinition> get recentTemplates => _recentTypeIds
      .map(_findTemplate)
      .whereType<RecordTypeDefinition>()
      .toList(growable: false);

  void setQuery(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == _query) return;
    _query = normalized;
    notifyListeners();
  }

  List<RecordTypeDefinition> templatesIn(
    TemplateCategory category, {
    required String Function(String stableId) localizedName,
  }) => templates
      .where((template) => template.category == category)
      .where((template) => _matches(template, localizedName))
      .toList(growable: false);

  void rememberSelection(String stableId) {
    if (_findTemplate(stableId) == null) return;
    _recentTypeIds = [
      stableId,
      ..._recentTypeIds.where((value) => value != stableId),
    ].take(maximumRecentTypes).toList(growable: false);
    notifyListeners();
  }

  bool _matches(
    RecordTypeDefinition template,
    String Function(String stableId) localizedName,
  ) {
    if (_query.isEmpty) return true;
    return template.defaultName.toLowerCase().contains(_query) ||
        localizedName(template.stableId).toLowerCase().contains(_query);
  }

  RecordTypeDefinition? _findTemplate(String stableId) {
    for (final template in templates) {
      if (template.stableId == stableId) return template;
    }
    return null;
  }

  static List<String> _sanitizeRecents(
    Iterable<String> values,
    Iterable<RecordTypeDefinition> templates,
  ) {
    final known = templates.map((template) => template.stableId).toSet();
    final result = <String>[];
    for (final value in values) {
      if (known.contains(value) && !result.contains(value)) result.add(value);
      if (result.length == maximumRecentTypes) break;
    }
    return List.unmodifiable(result);
  }
}
