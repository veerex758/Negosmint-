import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:negosmint_wallet/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wallet launches with branded splash', (tester) async {
    await tester.pumpWidget(const NegosMintWalletApp());
    expect(find.text('NegosMint Wallet'), findsOneWidget);
    expect(find.text('SEPOLIA TESTNET'), findsOneWidget);
  });
}
