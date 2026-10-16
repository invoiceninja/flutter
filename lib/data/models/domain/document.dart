import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';

part 'document.freezed.dart';

/// Domain attachment shared across entities (Company, Client, Product, …).
///
/// Mirrors the subset of [DocumentApi] the UI surfaces. `Document.toApi()`
/// lifts a domain object back to its API DTO so repositories can serialize
/// the array into Drift via the API's `toJson()` (the same round-trip
/// Company already uses for its `documents` column).
@freezed
abstract class Document with _$Document {
  const Document._();

  const factory Document({
    @Default('') String id,
    @Default('') String name,
    @Default('') String hash,
    @Default('') String type,
    // A token-gated API route (`/api/v1/documents/{id}/download`). Never
    // open it in a browser or hand it to `Image.network` — that gets
    // `{"message":"Invalid token"}`. Fetch the bytes with
    // `DocumentsApi.download` (`docs/document-urls.md`).
    @Default('') String url,
    @Default(0) int size,
    @Default(true) bool isPublic,
    @Default(0) int createdAt,
    @Default(0) int updatedAt,
  }) = _Document;

  factory Document.fromApi(DocumentApi api) => Document(
    id: api.id,
    name: api.name,
    hash: api.hash,
    type: api.type,
    url: api.url,
    size: api.size,
    isPublic: api.isPublic,
    createdAt: api.createdAt,
    updatedAt: api.updatedAt,
  );

  /// Lift back to the API DTO. Used by entity repositories when writing the
  /// `documents` JSON column on save — keeps the wire shape canonical.
  DocumentApi toApi() => DocumentApi(
    id: id,
    name: name,
    hash: hash,
    type: type,
    url: url,
    size: size,
    isPublic: isPublic,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
