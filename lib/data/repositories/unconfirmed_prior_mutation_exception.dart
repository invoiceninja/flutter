/// Thrown by `BaseEntityRepository.dedupPendingMutations` when a re-save of a
/// new record finds its earlier create `unconfirmed` — the server may already
/// have made the record. Queueing another create would make it twice, so the
/// save is refused (the transaction rolls back) and the form offers Check /
/// Resend / Discard for row [rowId] instead.
class UnconfirmedPriorMutationException implements Exception {
  const UnconfirmedPriorMutationException(this.rowId);

  final int rowId;

  @override
  String toString() =>
      'UnconfirmedPriorMutationException: outbox row $rowId may already '
      'have created this record';
}
