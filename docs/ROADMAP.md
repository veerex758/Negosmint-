# NegosMint Wallet Roadmap

## Phase 0 — Foundation
- Flutter foundation
- wallet module boundaries
- EVM network configuration
- secure storage boundary
- security-sensitive logging rules

## Phase 1 — Wallet foundation
- BIP-39 wallet creation
- recovery phrase verification
- wallet import/recovery
- BIP-44 address derivation
- secure key store
- wallet lock/unlock

## Phase 2 — Blockchain
- Ethereum Sepolia RPC
- chain validation
- native balance
- nonce
- gas estimation
- transaction builder

## Phase 3 — Receive
- [x] Address display with copy/selectable text
- [x] QR generation using an Ethereum Sepolia payment URI
- [x] Explicit network label and chain ID
- [x] Camera-based QR scanner
- [x] Strict address/payment URI validation (network and optional ETH amount)
- [x] Unit tests for valid and malformed payment payloads

## Phase 4 — Send
- [x] Recipient validation
- [x] Strict ETH amount validation and uint256 bounds
- [x] Transaction preview
- [x] Fee display and balance-plus-fee checks
- [x] Fresh authentication before signing
- [x] Local transaction signing
- [x] Signed transaction broadcast
- [x] Pending/confirmed/failed tracking from transaction receipts

Implementation note: live-device and real Sepolia transaction scenarios remain part of Phase 7 testnet validation.

## Phase 5 — Assets and activity
- [x] ERC-20 registry for user-added Sepolia contract addresses
- [x] Token metadata and balances via Sepolia RPC
- [x] Exact integer-based token decimal conversion (including tiny-balance display)
- [x] Native transfer and receipt-backed ERC-20 Transfer event parser
- [x] Sepolia explorer links for token contracts and transaction hashes
- [ ] Complete activity history, including inbound transaction discovery and persistent token-transfer indexing

Implementation note: ERC-20 metadata is untrusted contract-provided data. Tokens are manually added by address and this phase does not enable ERC-20 transfers or mainnet assets. Activity currently starts from locally recorded transaction hashes; discovering all inbound wallet activity requires an indexer or event/log scanning strategy.

## Phase 6 — Security hardening
- local PIN
- biometric/device authentication
- auto-lock
- sensitive-screen protection
- failed-attempt handling
- secret/logging audit
- backup/restore testing

## Phase 7 — Testnet validation
Test:
- create
- import
- backup/restore
- restart
- lock/unlock
- receive
- send
- insufficient balance
- insufficient gas
- wrong network
- invalid address
- RPC outage
- rejected/failed transaction

## Phase 8 — Production readiness
Security review and mainnet readiness assessment. Mainnet is enabled only after the wallet passes the security and recovery test process.
