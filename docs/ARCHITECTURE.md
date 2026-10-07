# NegosMint Wallet Architecture

NegosMint Wallet is a non-custodial EVM wallet. The wallet owns its keys and signs transactions locally.

## Security boundary

Private keys, recovery phrases, derived seeds, PIN secrets, and decrypted signing material never leave the device.

They must never be sent to:
- Supabase
- application servers
- analytics
- crash reporting
- logs
- admin dashboards

Only public wallet data and already-signed blockchain transactions may cross the boundary.

## Layers

1. Presentation — wallet screens and confirmation UI
2. Wallet State — initialized / locked / unlocked state
3. Wallet Core — orchestration and wallet lifecycle
4. Key Management — BIP-39/BIP-32/BIP-44 derivation and secure key storage
5. Transaction Engine — validation, nonce, gas, construction, local signing
6. Blockchain Provider — EVM RPC, chain validation and broadcasting
7. Asset System — native assets and ERC-20 assets
8. Security — device authentication, PIN, auto-lock and sensitive-screen protection
9. Storage — secure device storage plus non-secret local metadata

## Current V1 boundary

- One EVM network: Ethereum Sepolia while the wallet is under development
- BIP-44 Ethereum account: m/44'/60'/0'/0/0
- Native ETH balance and transfer foundation
- Recovery phrase creation and verification
- Secure local persistence
- Receive address and QR
- Transaction preparation, confirmation and local signing
- Transaction activity foundation

Mainnet is not enabled until the security and testnet validation process is complete.

## Explicit exclusions for V1

- dApp browser
- swaps
- staking
- NFT marketplace
- bridges
- smart-contract wallets
- hardware-wallet integration
- non-EVM chains
- large token catalogs

## Non-custodial rule

A server breach must not provide an attacker with the ability to spend from a user's wallet.
