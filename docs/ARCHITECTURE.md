# NegosMint Wallet Architecture

The Wallet owns private keys and signs blockchain transactions. The NegosMint Task App must never receive the wallet seed phrase or private keys.

## v1 modules
1. Wallet creation/recovery
2. Secure local key storage
3. Wallet address and QR receive flow
4. Send transaction flow
5. Token/network balances
6. Transaction history
7. Task App integration

## Security
- Never log seed phrases or private keys.
- Never commit secrets.
- Do not store private keys in plaintext.
- Validate chain/network before signing.
- Test with testnet assets before mainnet support.
