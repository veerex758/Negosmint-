class NetworkConfig {
  final int chainId;
  final String name;
  final String rpcUrl;
  final String explorerUrl;
  final String nativeSymbol;
  final int nativeDecimals;

  const NetworkConfig({
    required this.chainId,
    required this.name,
    required this.rpcUrl,
    required this.explorerUrl,
    required this.nativeSymbol,
    required this.nativeDecimals,
  });
}

class SupportedNetworks {
  static const sepolia = NetworkConfig(
    chainId: 11155111,
    name: 'Ethereum Sepolia',
    rpcUrl: 'https://ethereum-sepolia-rpc.publicnode.com',
    explorerUrl: 'https://sepolia.etherscan.io',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
  );
}
