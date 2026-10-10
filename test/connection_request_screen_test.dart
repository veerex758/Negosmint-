import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/network/network_config.dart';
import 'package:negosmint_wallet/screens/connection_request_screen.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_request.dart';

void main() {
  testWidgets(
    'connection approval is disabled when HTTPS callback setup fails',
    (tester) async {
      final request = WalletConnectionRequest(
        requestId: 'task-platform-callback',
        appName: 'NegosMint Task Platform',
        appIdentifier: 'com.negosmint.taskplatform',
        permissions: const [
          WalletConnectionPermission.readAddress,
          WalletConnectionPermission.readNetwork,
        ],
        chainId: SupportedNetworks.sepolia.chainId,
        callback: 'negosmint://wallet/callback',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(home: ConnectionRequestScreen(request: request)),
      );

      final errorFinder = find.textContaining(
        'A secure response callback could not be prepared',
      );
      await tester.scrollUntilVisible(
        errorFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(errorFinder, findsOneWidget);

      final connectButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect'),
      );
      expect(connectButton.onPressed, isNull);
    },
  );
}
