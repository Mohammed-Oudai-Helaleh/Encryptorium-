enum AesKeyLength {
  bits128(16),
  bits192(24),
  bits256(32);

  final int bytes;
  const AesKeyLength(this.bytes);

  String get displayName => '$bytes bytes (${bytes * 8} bits)';

  /// Returns all valid key lengths as a list of integers.
  static List<int> get validBytes => values.map((e) => e.bytes).toList();
}