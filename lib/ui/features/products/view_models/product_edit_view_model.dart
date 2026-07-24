import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the Product edit + create screen. Optimistic — `save()` lands
/// the draft in Drift via the repo, returns the saved entity, and the
/// outbox handles the server round-trip.
class ProductEditViewModel extends GenericEditViewModel<Product> {
  ProductEditViewModel({
    required this.repo,
    required this.companyId,
    Product? existing,
    Product? cloneFrom,
    super.useCommaAsDecimalPlace,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? _emptyProduct(),
         original: existing,
         companyId: companyId,
       );

  final ProductRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.productKey.isNotEmpty ||
        d.notes.isNotEmpty ||
        d.price != Decimal.zero ||
        d.cost != Decimal.zero;
  }

  @override
  Future<SaveResult<Product>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    // Flag an in-stock-quantity edit so the repo rides
    // `?update_in_stock_quantity=true` into the PUT — the server drops the
    // field otherwise. `original` is the server baseline captured when the
    // screen opened (non-null in the edit branch).
    final stockChanged = original?.inStockQuantity != draft.inStockQuantity;
    return repo.save(
      companyId: companyId,
      product: draft,
      stockChanged: stockChanged,
    );
  }

  void resetToEmpty() => reset(emptyDraft: _emptyProduct());

  // `setStr` / `setDec` / `setBool` live on the base; each setter just
  // names the `copyWith` projection. Compresses ~50 lines of duplicate
  // `updateDraft(draft.copyWith(...))` boilerplate. Closure params are
  // named `n` (next value) to avoid shadowing the outer setter argument.
  void setProductKey(String v) =>
      setStr((d, n) => d.copyWith(productKey: n), v);
  void setNotes(String v) => setStr((d, n) => d.copyWith(notes: n), v);
  void setPrice(String v) => setDec((d, n) => d.copyWith(price: n), v);
  void setCost(String v) => setDec((d, n) => d.copyWith(cost: n), v);
  void setQuantity(String v) => setDec((d, n) => d.copyWith(quantity: n), v);
  void setMaxQuantity(String v) =>
      setDec((d, n) => d.copyWith(maxQuantity: n), v);
  void setProductImage(String v) =>
      setStr((d, n) => d.copyWith(productImage: n), v);
  void setInStockQuantity(String v) =>
      setDec((d, n) => d.copyWith(inStockQuantity: n), v);
  void setStockNotification(bool v) =>
      setBool((d, n) => d.copyWith(stockNotification: n), v);
  void setStockNotificationThreshold(String v) =>
      setDec((d, n) => d.copyWith(stockNotificationThreshold: n), v);
  void setTaxId(String v) => setStr((d, n) => d.copyWith(taxId: n), v);
  void setTaxName1(String v) => setStr((d, n) => d.copyWith(taxName1: n), v);
  void setTaxRate1(String v) => setDec((d, n) => d.copyWith(taxRate1: n), v);
  void setTaxName2(String v) => setStr((d, n) => d.copyWith(taxName2: n), v);
  void setTaxRate2(String v) => setDec((d, n) => d.copyWith(taxRate2: n), v);
  void setTaxName3(String v) => setStr((d, n) => d.copyWith(taxName3: n), v);
  void setTaxRate3(String v) => setDec((d, n) => d.copyWith(taxRate3: n), v);
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));

  /// Atomically set a tax slot's name + rate from the bundled tax-rate
  /// picker. Takes a machine [Decimal] and bypasses the String-based
  /// `setTaxRateN` setters on purpose: routing the picker's value through
  /// `setDec` → `parseDecimal(useCommaAsDecimalPlace:)` would strip the
  /// decimal point under comma-decimal locales.
  void setTaxSlot(int slot, {required String name, required Decimal rate}) {
    switch (slot) {
      case 1:
        updateDraft(draft.copyWith(taxName1: name, taxRate1: rate));
      case 2:
        updateDraft(draft.copyWith(taxName2: name, taxRate2: rate));
      case 3:
        updateDraft(draft.copyWith(taxName3: name, taxRate3: rate));
    }
  }

  void setCustomValue1(String v) =>
      setStr((d, n) => d.copyWith(customValue1: n), v);
  void setCustomValue2(String v) =>
      setStr((d, n) => d.copyWith(customValue2: n), v);
  void setCustomValue3(String v) =>
      setStr((d, n) => d.copyWith(customValue3: n), v);
  void setCustomValue4(String v) =>
      setStr((d, n) => d.copyWith(customValue4: n), v);
}

Product _emptyProduct() => Product(
  id: '',
  productKey: '',
  notes: '',
  cost: Decimal.zero,
  price: Decimal.zero,
  quantity: Decimal.zero,
  maxQuantity: Decimal.zero,
  productImage: '',
  inStockQuantity: Decimal.zero,
  stockNotification: false,
  stockNotificationThreshold: Decimal.zero,
  taxName1: '',
  taxRate1: Decimal.zero,
  taxName2: '',
  taxRate2: Decimal.zero,
  taxName3: '',
  taxRate3: Decimal.zero,
  taxId: '',
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
