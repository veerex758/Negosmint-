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
- address display
- QR generation
- network labeling
- QR scanner and payment URI validation

## Phase 4 — Send
- recipient validation
- amount validation
- transaction preview
- fee display
- fresh authentication
- local signing
- signed transaction broadcast
- pending/confirmed/failed tracking

## Phase 5 — Assets and activity
- ERC-20 registry
- token balances
- decimals conversion
- transaction parser
- explorer links
- activity history

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
