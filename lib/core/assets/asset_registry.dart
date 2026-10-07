import '../network/network_config.dart';
import 'asset.dart';

class AssetRegistry {
  static const ethSepolia = Asset(
    symbol: 'ETH',
    name: 'Sepolia Ether',
    contractAddress: null,
    decimals: 18,
    chainId: 11155111,
    type: AssetType.native,
  );

  // Native Circle USDC on Ethereum Sepolia.
  // Source: Circle's official Ethereum USDC documentation.
  static const usdcSepolia = Asset(
    symbol: 'USDC',
    name: 'USD Coin',
    contractAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
    decimals: 6,
    chainId: 11155111,
    type: AssetType.erc20,
  );

  static const supported = <Asset>[
    ethSepolia,
    usdcSepolia,
  ];

  static Asset requireForChain(Asset asset, NetworkConfig network) {
    if (asset.chainId != network.chainId) {
      throw StateError('Asset does not belong to the selected network.');
    }
    return asset;
  }
}
