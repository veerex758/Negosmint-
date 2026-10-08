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
  final StreamController<WalletConnectionRequest> _controller =
      StreamController<WalletConnectionRequest>.broadcast();
  StreamSubscription<Uri>? _subscription;

  WalletDeepLinkReceiver({AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  Stream<WalletConnectionRequest> get requests => _controller.stream;

  Future<void> start() async {
    if (_subscription != null) return;

    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _emit(initial);
    }

    _subscription = _appLinks.uriLinkStream.listen(_emit);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  void _emit(Uri uri) {
    final request = _parse(uri);
    if (request != null && !_controller.isClosed) {
      _controller.add(request);
    }
  }

  WalletConnectionRequest? _parse(Uri uri) {
    try {
      if (uri.scheme != WalletConnectionCodec.scheme || uri.host != 'connect') {
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
