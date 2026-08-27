/// User column / sort-field id constants.
///
/// **This file must import nothing** — leaf by design, so `UserDao` can name a
/// sort field without pulling the Widget-bearing `user_columns.dart` into the
/// data layer. See `test/lint/layering_test.dart`.
///
/// `user_columns.dart` re-exports this file, so UI call sites are unchanged.
library;

/// Wire ids for sort + persisted column selection.
class UserFieldIds {
  static const String firstName = 'first_name';
  static const String lastName = 'last_name';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}
