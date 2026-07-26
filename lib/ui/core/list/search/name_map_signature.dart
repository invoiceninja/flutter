/// Order-independent content hash of an id → name map.
///
/// The token-search fields cache their `FilterKey` list and rebuild it only
/// when a shaping input actually changes — the cache has to be stable across
/// no-op Drift re-emits, because rebuilding it tears down and re-creates
/// `TagFilterKey`'s watch subscription.
///
/// Those name maps arrive as fresh instances on every emit, so the comparison
/// has to be by content. Doing that by sorting the entries and joining them
/// into one string is O(N log N) plus a large allocation — on **every build**,
/// which for a list VM means every page load, selection toggle, and
/// scroll-driven `loadMore`. A company with a few thousand clients pays a
/// multi-thousand-entry sort and a six-figure-character string per frame.
///
/// This folds instead: O(N), no allocation, and commutative so map iteration
/// order can't produce a spurious change. Collisions are theoretically possible
/// but cost only a redundant key rebuild, never a wrong render.
int nameMapSignature(Map<String, String> names) {
  var hash = names.length;
  for (final entry in names.entries) {
    // XOR-fold: commutative, so entry order is irrelevant.
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
