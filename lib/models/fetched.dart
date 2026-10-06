/// Something that was loaded, with when it was loaded and whether that was
/// from the internet just now or from a copy saved earlier.
class Fetched<T> {
  final T value;

  /// When [value] was loaded from the internet. For a saved copy, when it was
  /// saved.
  final DateTime fetchedAt;

  /// True when there was no connection, so [value] is a copy saved earlier.
  final bool fromCache;

  const Fetched(this.value, {required this.fetchedAt, this.fromCache = false});
}
