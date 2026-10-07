enum AssetType { native, erc20 }

class Asset {
  final String symbol;
  final String name;
  final String? contractAddress;
  final int decimals;
  final int chainId;
  final AssetType type;

  const Asset({
    required this.symbol,
    required this.name,
    required this.contractAddress,
    required this.decimals,
    required this.chainId,
    required this.type,
  });
}
