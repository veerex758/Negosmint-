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

Implementation note: the native ETH send path validates recipients and amounts, previews fees, re-checks network/balance/gas before local signing, broadcasts the signed transaction, and records its hash for receipt-based pending/confirmed/failed display. This change has not been run through CI or a live-device transaction test; maintainers should run those checks before treating Phase 4 as verified. Live-device and real Sepolia scenarios remain part of Phase 7 testnet validation.

## Phase 5 — Assets and activity
- [x] ERC-20 registry for user-added Sepolia contract addresses
- [x] Token metadata and balances via Sepolia RPC
- [x] Exact integer-based token decimal conversion (including tiny-balance display)
- [x] Native transfer and receipt-backed ERC-20 Transfer event parser
- [x] Sepolia explorer links for token contracts and transaction hashes
- [x] Persistent, deduplicated ERC-20 Transfer log index with a per-wallet scan cursor
- [x] Bounded initial inbound/outbound ERC-20 event discovery and incremental refresh
- [x] Paginated historical native transaction discovery and ERC-20 transfer history

Implementation note: ERC-20 metadata is untrusted contract-provided data. Tokens are manually added by address and this phase does not enable ERC-20 transfers or mainnet assets. The local RPC indexer scans the most recent 5,000 blocks on first use, persists deduplicated ERC-20 Transfer events and a cursor, and incrementally scans later blocks. A read-only, paginated Sepolia Blockscout address-history API supplements it so incoming native transactions and older transaction/token-transfer history can be discovered without scanning every block locally. Explorer history is best-effort and depends on the third-party indexer's availability; local sends and the RPC log index remain fallback sources. The wallet address is sent to the public explorer API, and no private keys or recovery phrases are sent. Failed RPC chunks do not advance the local cursor.

## Phase 6 — Security hardening
- [x] Local 6-digit PIN verifier stored as salted, iterated HMAC-SHA-256 output in platform secure storage; PIN itself is never stored
- [x] Biometric/device authentication preference with PIN fallback and safeguards against disabling all unlock methods
- [x] Configurable inactivity/background auto-lock (1, 5, 15, 30, or 60 minutes)
- [x] App-wide privacy overlay on backgrounding and clearing revealed recovery phrase from screen state
- [x] Failed PIN attempt counter with increasing temporary lockout after five failures
- [x] Prevent auto-lock navigation when no usable PIN or supported device-authentication method is configured
- [x] Unit tests for six-digit PIN validation policy and supported auto-lock durations
- [x] Secret/logging audit: no application debugPrint calls found; connection tests assert secrets are excluded from serialized payloads
- [x] Backup/recovery derivation tests for valid generated phrases, malformed phrases, and stable address/private-key derivation

### Phase 6 physical-device validation (2026-10-09)
- [x] Set and change the wallet PIN
- [x] Reject an incorrect PIN
- [x] Trigger the failed-attempt lockout
- [x] PIN fallback and other tested security flows, including auto-lock, background privacy behavior, recovery phrase handling, PIN removal, and recovery-phrase restore
- [ ] Biometric authentication — did not pass on the tested device; the user reports the system prompt does not appear both when enabling device authentication in Settings and when unlocking the wallet. Android host setup is being corrected to use `FlutterFragmentActivity` and declare `USE_BIOMETRIC`; rebuild and physical-device retest are still required.

Manual results were reported by the developer. The biometric failure is unresolved; do not treat Phase 6 as fully device-verified until it is diagnosed and retested. Automated CI/test results must also be green before merging.

## Phase 7 — Testnet validation

### Automated coverage
- [ ] CI passes with the new Sepolia RPC success/error/outage tests.
- [x] Add deterministic wallet transaction-gate tests for authentication, zero/negative native amounts, malformed recipients, missing wallet material, and malformed transaction data.
- [ ] Add persistence-backed wallet creation/import and restore tests, plus network-mocked balance-plus-fee and wrong-chain send tests.

The Sepolia RPC service now accepts an injectable endpoint so tests can use a local JSON-RPC server without contacting a public network. RPC tests cover chain-ID parsing, upstream JSON-RPC errors, HTTP 503 responses, malformed JSON, missing result fields, a refused connection, and a stalled response timeout. Separate wallet validation tests cover authentication and pre-network input gates. These tests are not considered passed until CI reports success.

### Physical-device / Sepolia testnet checklist
- [ ] Create wallet and complete recovery-phrase backup verification.
- [ ] Import an existing recovery phrase and verify the derived address.
- [ ] Restore from backup and confirm the same address and funds.
- [ ] Force-close/restart the app and confirm the wallet persists.
- [ ] Lock and unlock the wallet with the configured supported method.
- [ ] Receive Sepolia ETH and confirm the balance refreshes.
- [ ] Send a small Sepolia ETH transfer to a second test wallet; verify the hash and receipt status in the explorer.
- [ ] Verify insufficient balance is rejected before signing.
- [ ] Verify amount-plus-gas insufficiency is rejected before signing.
- [ ] Verify a wrong chain ID is rejected.
- [ ] Verify an invalid recipient address is rejected.
- [ ] Verify RPC outage/timeout displays a recoverable error and does not crash the app.
- [ ] Verify a rejected or reverted transaction is shown as failed and can be distinguished from pending.
- [ ] Confirm the activity screen reflects pending, confirmed, and failed receipt states.

### Validation rules
- Do not mark manual checks complete based only on unit tests or an APK build.
- Record the tested device, date, network, transaction hash (public only), and result for live Sepolia transactions.
- Sending currently requires operating-system authentication. The previously reported missing biometric prompt may block live send validation until that issue is resolved; do not bypass authentication to force a test.
- Use Sepolia test funds only. Never enter or share a recovery phrase or private key in an issue, log, or chat.

## Phase 8 — Production readiness
Security review and mainnet readiness assessment. Mainnet is enabled only after the wallet passes the security and recovery test process.


Phase 6 implementation note: the privacy overlay is Flutter-level best-effort protection against app-switcher snapshots; it does not yet provide a native Android FLAG_SECURE / iOS capture-blocking guarantee. PIN and preference records are stored using flutter_secure_storage. Device authentication uses the operating system prompt. Recovery tests verify BIP-39 phrase validity and deterministic derivation, but a full device-to-device restore drill, physical-device biometric/lockout checks, CI on the final Phase 6 commit, and security review remain release-validation tasks.
