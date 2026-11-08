import 'dart:async';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_document_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements DocuNinjaApi {
  var reads = 0;
  final pending = <Completer<DnDocument>>[];
  bool queueReads = false;
  Object? sendError;

  @override
  Future<DnDocument> document(String id) {
    reads++;
    if (!queueReads) {
      return Future.value(
        DnDocument.fromJson({
          'id': id,
          'status_id': 5,
          'description': '$reads',
        }),
      );
    }
    final c = Completer<DnDocument>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<List<DnTimelineEntry>> timeline(String id) async => const [];

  @override
  Future<void> send(String id, List<DnInvitation> invitations) async {
    if (sendError != null) throw sendError!;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The document page's view model.
void main() {
  test('a failed send re-reads: it may have landed all the same', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentViewModel(api: api, id: 'd1');
    await vm.load();
    expect(api.reads, 1);
    api.sendError = const DocuNinjaException(408, 'timed out');
    expect(await vm.send(), isFalse);
    expect(api.reads, 2, reason: 'the page shows what DocuNinja holds');
    vm.dispose();
  });

  test('an older read that lands last is dropped', () async {
    final api = _Api()..queueReads = true;
    final vm = DocuNinjaDocumentViewModel(api: api, id: 'd1');
    final first = vm.load();
    final second = vm.load();
    api.pending[1].complete(
      DnDocument.fromJson({'id': 'd1', 'status_id': 8, 'description': 'new'}),
    );
    await second;
    api.pending[0].complete(
      DnDocument.fromJson({'id': 'd1', 'status_id': 5, 'description': 'old'}),
    );
    await first;
    expect(vm.document?.description, 'new');
    expect(vm.isLoading, isFalse);
    vm.dispose();
  });
}
