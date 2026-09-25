/// Thrown by `BaseEntityRepository.dedupPendingMutations` when a re-save of a
/// new record finds that its temp id has already landed — an earlier attempt
/// made the record, under real id [realId], which the form never learned.
/// Queueing another create would make it twice, so the save is refused (the
/// transaction rolls back, leaving no local copy behind).
class CreateAlreadyLandedException implements Exception {
  const CreateAlreadyLandedException(this.realId);

  final String realId;

  @override
  String toString() =>
      'CreateAlreadyLandedException: this record was already created as '
      '$realId';
}
