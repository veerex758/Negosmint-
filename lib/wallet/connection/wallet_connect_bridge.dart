import 'dart:async';

import 'package:reown_walletkit/reown_walletkit.dart';

import '../../core/wallet/wallet_service.dart';
import 'wallet_connection_request.dart';
import 'wallet_connect_transaction_parser.dart';
import 'wallet_signing_request.dart';

class WalletConnectProposal {
  final int id;
  final String appName;
  final String appDescription;
  final String appUrl;
  final String pairingTopic;
  final List<String> requiredChains;
  final List<String> requiredMethods;
  final List<String> requiredEvents;
  final DateTime expiresAt;

  const WalletConnectProposal({
    required this.id,
    required this.appName,
    required this.appDescription,
    required this.appUrl,
    required this.pairingTopic,
    required this.requiredChains,
    required this.requiredMethods,
    required this.requiredEvents,
    required this.expiresAt,
  });

  bool get requestsSigning => requiredMethods.contains('eth_sendTransaction');
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}

class WalletConnectSessionRequest {
  final String topic;
  final int id;
  final String chainId;
  final String method;
  final WalletSigningRequest? signingRequest;
  final String appName;
  final String? from;

  const WalletConnectSessionRequest({
    required this.topic,
    required this.id,
    required this.chainId,
    required this.method,
    required this.signingRequest,
    required this.appName,
    required this.from,
  });
}

class WalletConnectBridge {
  final ReownWalletKit walletKit;

  WalletConnectBridge._(this.walletKit);

  final StreamController<WalletConnectProposal> _proposals =
      StreamController<WalletConnectProposal>.broadcast();
  final StreamController<WalletConnectSessionRequest> _requests =
      StreamController<WalletConnectSessionRequest>.broadcast();

  static const _supportedMethods = {
    'eth_chainId',
    'eth_accounts',
    'eth_requestAccounts',
    'eth_getBalance',
    'eth_getCode',
    'eth_getTransactionByHash',
    'eth_getTransactionReceipt',
    'eth_blockNumber',
    'eth_call',
    'eth_estimateGas',
    'eth_gasPrice',
    'eth_getBlockByNumber',
    'eth_getBlockByHash',
    'net_version',
    'eth_sendTransaction',
  };

  static const _supportedEvents = {'chainChanged', 'accountsChanged'};

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

    final bridge = WalletConnectBridge._(walletKit);
    walletKit.onSessionProposal.subscribe(bridge._onProposal);
    walletKit.onSessionRequest.subscribe(bridge._onSessionRequest);
    return bridge;
  }

  Stream<WalletConnectProposal> get proposals => _proposals.stream;
  Stream<WalletConnectSessionRequest> get requests => _requests.stream;

  Future<PairingInfo> pair(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'wc') {
      throw const WalletConnectionException(
        'Unsupported wallet connection URI.',
      );
    }
    return walletKit.pair(uri: uri);
  }

  Future<void> approve({
    required WalletConnectProposal proposal,
    required WalletService walletService,
  }) async {
    if (proposal.isExpired || !_isSupportedProposal(proposal)) {
      throw const WalletConnectionException(
        'This session requires unsupported permissions or networks.',
      );
    }

    final address = await walletService.getPublicAddress();
    if (!_isEvmAddress(address)) {
      throw const WalletConnectionException('Wallet address is invalid.');
    }

    await walletKit.approveSession(
      id: proposal.id,
      namespaces: {
        'eip155': Namespace(
          accounts: ['eip155:11155111:$address'],
          methods: List.unmodifiable(_supportedMethods),
          events: List.unmodifiable(_supportedEvents),
        ),
      },
    );
  }

  Future<void> reject(int proposalId) async {
    await walletKit.rejectSession(
      id: proposalId,
      reason: Errors.getSdkError(Errors.USER_REJECTED).toSignError(),
    );
  }

  Map<String, SessionData> get activeSessions =>
      Map.unmodifiable(walletKit.getActiveSessions());

  Future<void> disconnect({
    required String topic,
    required ReownSignError reason,
  }) =>
      walletKit.disconnectSession(topic: topic, reason: reason);

  void _onProposal(SessionProposalEvent? event) {
    if (event == null || _proposals.isClosed) return;
    final proposal = event.params;
    final eip155 = proposal.requiredNamespaces['eip155'];
    if (eip155 == null) return;

    _proposals.add(
      WalletConnectProposal(
        id: event.id,
        appName: proposal.proposer.metadata.name,
        appDescription: proposal.proposer.metadata.description,
        appUrl: proposal.proposer.metadata.url,
        pairingTopic: proposal.pairingTopic,
        requiredChains: List.unmodifiable(eip155.chains ?? const <String>[]),
        requiredMethods: List.unmodifiable(eip155.methods),
        requiredEvents: List.unmodifiable(eip155.events),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          proposal.expiry * 1000,
          isUtc: true,
        ),
      ),
    );
  }

  bool _isSupportedProposal(WalletConnectProposal proposal) {
    const sepolia = 'eip155:11155111';
    return proposal.requiredChains.length == 1 &&
        proposal.requiredChains.single == sepolia &&
        proposal.requiredMethods.every(_supportedMethods.contains) &&
        proposal.requiredEvents.every(_supportedEvents.contains);
  }

  static bool _isEvmAddress(String? value) =>
      value != null && RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);

  Future<void> respondRejected(WalletConnectSessionRequest request) async {
    await respondError(
      request,
      code: 4001,
      message: 'User rejected the request.',
    );
  }

  Future<void> respondError(
    WalletConnectSessionRequest request, {
    required int code,
    required String message,
  }) async {
    await walletKit.respondSessionRequest(
      topic: request.topic,
      response: JsonRpcResponse(
        id: request.id,
        error: JsonRpcError(code: code, message: message),
      ),
    );
  }

  Future<void> respondTransactionHash(
    WalletConnectSessionRequest request,
    String transactionHash,
  ) async {
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(transactionHash)) {
      throw const WalletConnectionException('Invalid transaction hash.');
    }
    await walletKit.respondSessionRequest(
      topic: request.topic,
      response: JsonRpcResponse(
        id: request.id,
        result: transactionHash,
      ),
    );
  }

  void _onSessionRequest(SessionRequestEvent? event) {
    if (event == null || _requests.isClosed) return;
    final request = event.params;
    final session = walletKit.getActiveSessions()[request.topic];

    if (session == null) {
      return;
    }

    try {
      final normalized = WalletConnectTransactionParser.parse(
        topic: request.topic,
        id: request.id,
        chainId: request.chainId,
        methodName: request.method,
        params: request.params,
        appName: session.peer.metadata.name,
      );
      _requests.add(
        WalletConnectSessionRequest(
          topic: normalized.signingRequest.sessionId,
          id: request.id,
          chainId: request.chainId,
          method: request.method,
          signingRequest: normalized.signingRequest,
          appName: session.peer.metadata.name,
          from: normalized.from,
        ),
      );
    } on WalletConnectionException catch (error) {
      _respondProtocolError(
        topic: request.topic,
        id: request.id,
        code: _protocolErrorCode(error),
        message: _safeProtocolMessage(error),
      );
    } catch (_) {
      _respondProtocolError(
        topic: request.topic,
        id: request.id,
        code: -32600,
        message: 'Invalid request.',
      );
    }
  }

  int _protocolErrorCode(WalletConnectionException error) {
    final message = error.message.toLowerCase();
    if (message.contains('unsupported')) return 4200;
    if (message.contains('malformed') || message.contains('invalid')) {
      return -32602;
    }
    return -32600;
  }

  String _safeProtocolMessage(WalletConnectionException error) {
    final message = error.message.toLowerCase();
    if (message.contains('unsupported'))
      return 'Unsupported method or network.';
    if (message.contains('malformed') || message.contains('invalid')) {
      return 'Invalid request parameters.';
    }
    return 'Invalid request.';
  }

  Future<void> _respondProtocolError({
    required String topic,
    required int id,
    required int code,
    required String message,
  }) async {
    try {
      await walletKit.respondSessionRequest(
        topic: topic,
        response: JsonRpcResponse(
          id: id,
          error: JsonRpcError(code: code, message: message),
        ),
      );
    } catch (_) {
      // The request may have expired or the session may have disconnected.
    }
  }

  Future<void> dispose() async {
    await _proposals.close();
    await _requests.close();
  }
}
