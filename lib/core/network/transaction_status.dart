enum SepoliaTransactionStatus { pending, confirmed, failed }

/// Interprets the JSON-RPC receipt status without guessing on malformed data.
class SepoliaTransactionStatusParser {
  static SepoliaTransactionStatus parse(Map<String, dynamic>? receipt) {
    if (receipt == null) return SepoliaTransactionStatus.pending;
    switch (receipt['status']) {
      case '0x1':
        return SepoliaTransactionStatus.confirmed;
      case '0x0':
        return SepoliaTransactionStatus.failed;
      default:
        return SepoliaTransactionStatus.pending;
    }
  }
}
