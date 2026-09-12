/// Returns whether [a] and [b] have the same length and every pair of
/// elements at the same index is considered equal by [equals].
///
/// Used by stores to decide whether a freshly-loaded list actually changes
/// the cached state before calling `notifyListeners()`. The fields compared
/// stay explicit at each call site (via [equals]) rather than relying on a
/// model's `==`, since several models intentionally define `==` by id only
/// (for lookup purposes) and need a separate, full-field comparison here.
bool listContentEquals<T>(
  List<T> a,
  List<T> b,
  bool Function(T a, T b) equals,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!equals(a[i], b[i])) return false;
  }
  return true;
}
