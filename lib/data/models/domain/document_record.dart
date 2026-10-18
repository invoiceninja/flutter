import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/entity_type.dart';

part 'document_record.freezed.dart';

/// One uploaded file as a row of the company-wide Documents list
/// (`GET /api/v1/documents`), as opposed to [Document], the same file
/// embedded in its record's `documents` array.
///
/// Deliberately carries no `url`: that is a token-gated API route a browser
/// can't open (`docs/document-urls.md`). View and download go through
/// [attachment] → `viewDocument` / `downloadDocument`, which fetch the bytes
/// with the API token.
///
/// [parentType] / [parentId] name the record the file is attached to when the
/// app knows it — an older server's list response doesn't say
/// (`docs/documents-list.md`). `isDirty` and `isDeleted` are overlaid by the
/// repository from the Drift row; `fromApi` defaults both to `false`.
@freezed
abstract class DocumentRecord with _$DocumentRecord {
  const DocumentRecord._();

  const factory DocumentRecord({
    required String id,
    required String name,
    required String type,
    required String hash,
    required int size,
    required int width,
    required int height,
    required bool isPublic,
    required String userId,
    required String assignedUserId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime? archivedAt,
    @Default(false) bool isDeleted,
    @Default(false) bool isDirty,
    EntityType? parentType,
    String? parentId,
  }) = _DocumentRecord;

  factory DocumentRecord.fromApi(
    DocumentApi a, {
    EntityType? parentType,
    String? parentId,
  }) => DocumentRecord(
    id: a.id,
    name: a.name,
    type: a.type,
    hash: a.hash,
    size: a.size,
    width: a.width,
    height: a.height,
    isPublic: a.isPublic,
    userId: a.userId,
    assignedUserId: a.assignedUserId,
    createdAt: epochSecondsToUtc(a.createdAt),
    updatedAt: epochSecondsToUtc(a.updatedAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    parentType: parentType,
    parentId: parentId,
  );

  /// The same file in the shape the shared viewer / download helpers take.
  ///
  /// `url` stays empty on purpose — nothing may open it (see the class doc),
  /// and those helpers fetch by id.
  Document get attachment => Document(
    id: id,
    name: name,
    hash: hash,
    type: type,
    size: size,
    isPublic: isPublic,
    createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
    updatedAt: updatedAt.millisecondsSinceEpoch ~/ 1000,
  );

  /// The name to show, falling back to the content hash for an unnamed file
  /// so a row never renders blank.
  String get displayName => name.trim().isNotEmpty ? name : hash;

  /// Pixel dimensions, or null for a file that isn't an image.
  ({int width, int height})? get dimensions =>
      width > 0 && height > 0 ? (width: width, height: height) : null;
}
