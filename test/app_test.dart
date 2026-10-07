import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/app.dart';

void main() {
  testWidgets('wallet app starts with NegosMint branding', (tester) async {
    await tester.pumpWidget(const NegosMintWalletApp());
    expect(find.text('NegosWallet'), findsOneWidget);
  });
}
