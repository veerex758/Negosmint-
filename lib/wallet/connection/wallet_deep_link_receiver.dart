import 'dart:async';

import 'package:app_links/app_links.dart';

import 'wallet_connection_codec.dart';
import 'wallet_connection_request.dart';

/// Receives OS deep links and exposes only validated connection requests.
///
/// Platform registration (Android/iOS intent configuration) remains separate.
/// This receiver does not navigate the UI and never handles wallet secrets.
class WalletDeepLinkReceiver {
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  WalletDeepLinkReceiver({AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  Future<WalletConnectionRequest?> getInitialRequest() async {
    final uri = await _appLinks.getInitialLink();
    if (uri == null) return null;
    return _parse(uri);
  }

  Stream<WalletConnectionRequest> listen() {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.map(_parse).whereType<WalletConnectionRequest>();
    return _subscriptionStream;
  }

  Stream<WalletConnectionRequest> get _subscriptionStream {
    // Re-create from the plugin stream so the returned stream is broadcast-safe
    // for the app lifecycle without exposing the raw URI outside this boundary.
    return _appLinks.uriLinkStream.map(_parse).whereType<WalletConnectionRequest>();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  WalletConnectionRequest? _parse(Uri uri) {
    try {
      if (uri.scheme != WalletConnectionCodec.scheme ||
          uri.host != 'connect') {
        return null;
      }
      return WalletConnectionCodec.parseRequest(uri.toString());
    } on WalletConnectionException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
