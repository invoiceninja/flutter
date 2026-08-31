import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';

/// How a column's contents align inside its allocated width.
enum ColumnAlign { start, end }

/// Marks a column as one of an entity's four company-configurable custom-field
/// slots.
///
/// Carried by the **raw** registry entry; `GenericListViewModel.availableColumns`
/// runs `decorateCustomFieldColumns` over it to resolve the company's own label,
/// pick a type-aware renderer, and drop the column entirely when the company
/// hasn't configured that slot.
@immutable
class CustomFieldSlot<T> {
  const CustomFieldSlot({
    required this.prefix,
    required this.index,
    required this.valueOf,
  }) : assert(index >= 1 && index <= 4);

  /// Key prefix into `Company.customFields` — deliberately **not** the entity
  /// name. Quotes, credits, purchase orders and recurring invoices all read the
  /// `invoice1..4` slots; recurring expenses read `expense1..4`.
  final String prefix;

  /// 1-4.
  final int index;

  /// The raw stored `custom_value<index>`. Never formatted — the decorator
  /// applies `Company.customFieldDisplay` on top for switch / date slots.
  final String Function(T entity) valueOf;

  /// `client1`, `invoice3`, … — the key into `Company.customFields`.
  String get companyKey => '$prefix$index';
}

/// Declarative description of one column in a list view's table layout.
///
/// `id` is the wire identifier — must match the snake_case constants the
/// old admin-portal stores in `userCompany.settings.table_columns` (see
/// `admin-portal/lib/data/models/client_model.dart` `ClientFields.*`).
/// Renaming an id breaks compatibility with the existing app's saved
/// preferences, so don't.
///
/// `width` is fixed in logical pixels; if null, the column flexes (used by
/// the identity column only — there should be at most one flex column per
/// row to keep header/row alignment trivial).
class ColumnDefinition<T> {
  const ColumnDefinition({
    required this.id,
    required this.labelKey,
    required this.cellBuilder,
    this.valueBuilder,
    this.width,
    this.align = ColumnAlign.start,
    this.sortable = true,
    this.label,
    this.customField,
  });

  final String id;
  // Localization key for the column header. Resolve via
  // `column.resolveLabel(context)` — NOT `context.tr(labelKey)` directly, or a
  // custom-field column loses the company's own label.
  final String labelKey;

  /// Already-resolved header text that **wins over** [labelKey].
  ///
  /// Only `decorateCustomFieldColumns` sets it, to the company's configured
  /// custom-field name ("Region"). That is user data, so it has no translation
  /// key and can't go through [labelKey].
  final String? label;

  /// Non-null on the four raw custom-field slots. See [CustomFieldSlot].
  final CustomFieldSlot<T>? customField;
  final double? width;
  final ColumnAlign align;
  final Widget Function(T entity, BuildContext context) cellBuilder;

  /// Canonical, copyable string for this cell (raw decimal for money, ISO
  /// for dates, untrimmed string for text). When null or returns an empty
  /// string the cell has nothing copy-worthy and the hover-copy affordance
  /// is suppressed.
  final String? Function(T entity)? valueBuilder;

  /// Whether this column can back a sort. Every header is a sort control, and
  /// the DAOs' `_sortExpression` throws `ArgumentError` on a field it has no
  /// case for — so a column whose value lives only in the row payload (tags,
  /// notes, a derived status, a foreign-key "View" link) has no Drift column
  /// to order by and **must** set this false. Enforced by
  /// `test/domain/columns/sortable_columns_test.dart`.
  final bool sortable;

  bool get isFlex => width == null;

  /// Header / picker text: the company's own label when this column carries one
  /// (custom-field slots), otherwise the translated [labelKey].
  String resolveLabel(BuildContext context) => label ?? context.tr(labelKey);

  /// Copy carrying the company's resolved [label] and, for switch / date slots,
  /// a company-aware [cellBuilder]. Everything else is carried verbatim.
  ///
  /// Deliberately NOT a general `copyWith`: `width == null` is the "flex"
  /// sentinel ([isFlex]), so a general copyWith would need a *second* sentinel
  /// to tell "keep 140" from "make me flex" — for exactly one caller that never
  /// touches width.
  ColumnDefinition<T> withResolvedLabel({
    required String label,
    Widget Function(T entity, BuildContext context)? cellBuilder,
  }) => ColumnDefinition<T>(
    id: id,
    labelKey: labelKey,
    cellBuilder: cellBuilder ?? this.cellBuilder,
    valueBuilder: valueBuilder,
    width: width,
    align: align,
    sortable: sortable,
    label: label,
    customField: customField,
  );
}

/// True when [field] names a known, sortable column.
///
/// This is the gate behind every list ViewModel's `isValidColumnId`, which
/// guards all three ways a sort field is set: the header tap (`setSort`), the
/// persisted `nav_state` restore, and deep-link sort intents. Rejecting
/// display-only columns here is what keeps an unmapped field from reaching a
/// DAO — see [ColumnDefinition.sortable].
bool isSortableColumnId<T>(
  Map<String, ColumnDefinition<T>> columnsById,
  String field,
) => columnsById[field]?.sortable ?? false;
