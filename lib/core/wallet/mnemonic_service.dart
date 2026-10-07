import 'package:wallet/wallet.dart' as wallet;

/// BIP-39/BIP-32 operations are delegated to the audited [wallet] package.
/// This class intentionally contains no persistence.
class MnemonicService {
  List<String> generate() => wallet.generateMnemonic(strength: 128);

  bool validate(List<String> words) => wallet.validateMnemonic(words);

  List<int> toSeed(List<String> words) => wallet.mnemonicToSeed(words);

  String deriveEvmAddress(List<String> words) {
    final seed = wallet.mnemonicToSeed(words);
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final child =
        master.forPath("m/44'/60'/0'/0/0") as wallet.ExtendedPrivateKey;
    final privateKey = wallet.PrivateKey(child.key);
    final publicKey = wallet.ethereum.createPublicKey(privateKey);
    return wallet.EthereumAddress.fromPublicKey(publicKey).eip55With0x;
  }

  String derivePrivateKeyHex(List<String> words) {
    final seed = wallet.mnemonicToSeed(words);
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final child =
        master.forPath("m/44'/60'/0'/0/0") as wallet.ExtendedPrivateKey;
    return child.key.toRadixString(16).padLeft(64, '0');
  }
}
