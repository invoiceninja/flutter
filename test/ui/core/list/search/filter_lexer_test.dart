import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_lexer.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

void main() {
  group('lexFilterInput', () {
    test('treats input with no colon as free text', () {
      final result = lexFilterInput('alpha bravo', [_FakeKey('country', [])]);
      expect(result.tokens, isEmpty);
      expect(result.freeText, 'alpha bravo');
    });

    test('parses a single key:value pair', () {
      final result = lexFilterInput('country:US', [_FakeKey('country', [])]);
      expect(result.tokens, [(keyId: 'country', rawValue: 'US')]);
      expect(result.freeText, isEmpty);
    });

    test('resolves an alias to the canonical key id', () {
      final result = lexFilterInput('status:active', [
        _FakeKey('is', ['status']),
      ]);
      expect(result.tokens, [(keyId: 'is', rawValue: 'active')]);
    });

    test('a quoted value is one value, spaces and all', () {
      final result = lexFilterInput('country:"United States" acme', [
        _FakeKey('country', []),
      ]);
      // It used to split on the space first: `"United` was the value and
      // `States"` went into the search.
      expect(result.tokens, [(keyId: 'country', rawValue: 'United States')]);
      expect(result.freeText, 'acme');
    });

    test('an unterminated quote is a literal character', () {
      final result = lexFilterInput('name:"acme corp', [_FakeKey('name', [])]);
      expect(result.tokens, [(keyId: 'name', rawValue: '"acme')]);
      expect(result.freeText, 'corp');
    });

    test('comma-separated values of a pick-only key are several values', () {
      final result = lexFilterInput('is:active,archived', [
        _FakeKey('is', [], typed: false),
      ]);
      expect(result.tokens, [
        (keyId: 'is', rawValue: 'active'),
        (keyId: 'is', rawValue: 'archived'),
      ]);
    });

    test('a typed value keeps its commas — the key reads them', () {
      final keys = [_FakeKey('date', []), _FakeKey('balance', [])];
      // A date window, a date with a comma in it, a decimal comma.
      expect(lexFilterInput('date:2026-01-01,2026-02-01', keys).tokens, [
        (keyId: 'date', rawValue: '2026-01-01,2026-02-01'),
      ]);
      expect(lexFilterInput('date:"May 14, 2026"', keys).tokens, [
        (keyId: 'date', rawValue: 'May 14, 2026'),
      ]);
      expect(lexFilterInput('balance:1,5', keys).tokens, [
        (keyId: 'balance', rawValue: '1,5'),
      ]);
    });

    test('a quoted value of a pick-only key is not split', () {
      final result = lexFilterInput('tag:"a,b"', [
        _FakeKey('tag', [], typed: false),
      ]);
      expect(result.tokens, [(keyId: 'tag', rawValue: 'a,b')]);
    });

    test('unknown prefix falls through as free text', () {
      final result = lexFilterInput('zzz:bar real', [_FakeKey('country', [])]);
      expect(result.tokens, isEmpty);
      expect(result.freeText, 'zzz:bar real');
    });

    test('mixes tokens and free text', () {
      final result = lexFilterInput('hello country:US world', [
        _FakeKey('country', []),
      ]);
      expect(result.tokens, [(keyId: 'country', rawValue: 'US')]);
      expect(result.freeText, 'hello world');
    });
  });
}

class _FakeKey extends FilterKey {
  _FakeKey(this._id, this._aliases, {this.typed = true});
  final String _id;
  final List<String> _aliases;
  final bool typed;

  @override
  bool get acceptsTypedValue => typed;

  @override
  String get id => _id;

  @override
  Iterable<String> get aliases => _aliases;

  @override
  String displayLabel(BuildContext context) => _id;

  @override
  FilterValueType get valueType => FilterValueType.string;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) => true;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) => const [];

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => Stream.value(const []);

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      Future.value();

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      Future.value();
}
