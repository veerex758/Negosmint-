import 'package:reown_walletkit/reown_walletkit.dart';

/// Thin interoperability boundary around Reown WalletKit.
///
/// This class owns WalletConnect/Reown protocol state only. It does not own
/// wallet keys and never receives a seed phrase, private key, PIN, or
/// decrypted key material.
class WalletConnectBridge {
  final ReownWalletKit walletKit;

  WalletConnectBridge._(this.walletKit);

  /// Creates the protocol client. [projectId] is a public Reown project
  /// identifier; it is not a wallet secret.
  static Future<WalletConnectBridge> create({
    required String projectId,
    String name = 'NegosWallet',
    String description = 'NegosMint self-custody wallet',
    String url = 'https://negosmint.com',
    List<String> icons = const [],
  }) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) {
      throw const WalletConnectionException(
        'WalletConnect project ID is not configured.',
      );
    }

    final walletKit = await ReownWalletKit.createInstance(
      projectId: normalizedProjectId,
      metadata: PairingMetadata(
        name: name,
        description: description,
        url: url,
        icons: icons,
      ),
    );

    return WalletConnectBridge._(walletKit);
  }

  /// Accepts a standard WalletConnect URI and starts pairing.
  ///
  /// Pairing does not approve a session. The wallet must still present the
  /// incoming proposal to the user and explicitly approve or reject it.
  Future<PairingInfo> pair(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'wc') {
      throw const WalletConnectionException(
        'Unsupported wallet connection URI.',
      );
    }
    return walletKit.pair(uri: uri);
  }

  Map<String, SessionData> get activeSessions =>
      Map.unmodifiable(walletKit.getActiveSessions());

  Future<void> disconnect({
    required String topic,
    required ReownSignError reason,
  }) =>
      walletKit.disconnectSession(topic: topic, reason: reason);
}
