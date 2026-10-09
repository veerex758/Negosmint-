enum SepoliaTransactionStatus { pending, confirmed, failed }

/// Interprets the JSON-RPC receipt status without guessing on malformed data.
class SepoliaTransactionStatusParser {
  static SepoliaTransactionStatus parse(Map<String, dynamic>? receipt) {
    if (receipt == null) return SepoliaTransactionStatus.pending;
    final raw = receipt['status'];
    if (raw is! String || !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(raw)) {
      return SepoliaTransactionStatus.pending;
    }
    final status = BigInt.tryParse(raw.substring(2), radix: 16);
    if (status == BigInt.one) return SepoliaTransactionStatus.confirmed;
    if (status == BigInt.zero) return SepoliaTransactionStatus.failed;
    return SepoliaTransactionStatus.pending;
  }
}
