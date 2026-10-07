import 'mnemonic_service.dart';
import 'secure_key_store.dart';
import 'wallet_state.dart';

class WalletCore {
  final MnemonicService mnemonicService;
  final SecureKeyStore keyStore;
  final WalletState state;

  WalletCore({
    MnemonicService? mnemonicService,
    SecureKeyStore? keyStore,
    WalletState? state,
  })  : mnemonicService = mnemonicService ?? MnemonicService(),
        keyStore = keyStore ?? const SecureKeyStore(),
        state = state ?? WalletState();

  Future<bool> hasWallet() => keyStore.hasWallet();

  Future<String> createAndStore(List<String> mnemonic) async {
    if (!mnemonicService.validate(mnemonic)) {
      throw StateError('Invalid recovery phrase.');
    }
    final address = mnemonicService.deriveEvmAddress(mnemonic);
    await keyStore.saveMnemonic(mnemonic);
    await keyStore.saveAddress(address);
    state.initialized(address: address);
    return address;
  }

  Future<String?> restore() async {
    final mnemonic = await keyStore.loadMnemonic();
    if (mnemonic == null || !mnemonicService.validate(mnemonic)) return null;
    final address = mnemonicService.deriveEvmAddress(mnemonic);
    await keyStore.saveAddress(address);
    state.initialized(address: address);
    return address;
  }

  Future<String> deriveSigningKeyHex() async {
    final mnemonic = await keyStore.loadMnemonic();
    if (mnemonic == null) throw StateError('Wallet is not initialized.');
    if (!state.isUnlocked) throw StateError('Wallet is locked.');
    return mnemonicService.derivePrivateKeyHex(mnemonic);
  }

  Future<void> lock() async => state.lock();

  Future<void> destroy() async {
    await keyStore.deleteWallet();
    state.reset();
  }
}
