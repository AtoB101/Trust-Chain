# M2.0 Stable Settlement Profile v0.1

This profile introduces a first on-chain settlement safety baseline for stablecoin-oriented flows.

## Goals

- constrain bill creation to explicitly allowed tokens when enforcement is enabled
- prevent dust-level bill creation via minimum bill amount
- keep rollout controlled with owner-managed toggles
- expose profile state directly in frontend health checks and evidence exports

## Contract controls

Implemented in `NonCustodialAgentPayment`:

- `setStableTokenEnforcement(bool enabled)`
  - when enabled, `createBill` requires token allowlist approval
- `setStableTokenAllowed(address token, bool allowed)`
  - owner-managed stable token allowlist flag
- `setMinSettlementAmount(uint256 amount)`
  - global minimum principal amount for `createBill`

Views:

- `stableTokenEnforcementEnabled()`
- `isStableTokenAllowed(address token)`
- `minSettlementAmount()`

Events:

- `StableTokenEnforcementUpdated(bool enabled)`
- `StableTokenAllowedUpdated(address indexed token, bool allowed)`
- `MinSettlementAmountUpdated(uint256 amount)`

## Enforcement points

### `createBill(...)`

Now checks:

1. `amount >= minSettlementAmount`
2. if `stableTokenEnforcementEnabled == true`, then `isStableTokenAllowed(token) == true`

## Frontend operations panel (M2.0)

In `examples/v01-metamask-settlement.html`, stable profile controls are available in:

- **Stable settlement profile (M2.0)** section
- Inputs:
  - `stableEnforcementEnabled`
  - `stableMinAmount`
  - `stableTokenRule`
  - `stableTokenAllowed`
- Actions:
  - `Apply stable profile` (updates enforcement + min amount)
  - `Set stable token rule` (updates token allowlist)
  - `Refresh stable profile` (reads current on-chain state)

Health check (`Run Health Check`) also reads stable profile and emits `stable_settlement` diagnostics.

## Evidence integration (M2.1)

Exported diagnosis JSON now carries stable profile context in three places:

- `authSnapshot.stableSettlementSnapshot`
- `requestSnapshot.stableSettlementDecision`
- `riskSnapshot.stableSettlement`

## Evidence integration (M2.3 extension)

Stable profile change history now includes richer operation metadata under:

- `authSnapshot.stableConfigHistory[]`

Each history item includes:

- `version` (monotonic local version counter in UI session)
- `action` (for example: `apply_profile`, `set_token_rule`)
- `reason` (operator-supplied change reason)
- `operator` (operator label, for example `alice@ops`)
- `tokenAddress`
- `tokenAllowed`
- `enforcementEnabled`
- `minSettlementAmount`
- `txHashes` (transaction hash references per change operation)

This allows audit/support to answer:

- Was stable enforcement enabled at operation time?
- Was the active token allowlisted?
- Was the configured amount above minimum threshold?
- Did stable settlement constraints contribute to readiness outcome?

## Evidence integration (M2.4 hash-chain extension)

To strengthen tamper-evidence for local operation history, each stable config history item now
includes chained digests:

- `prevHash` (hash pointer to previous history record in this session; `null` on first record)
- `currentHash` (hash of canonicalized record content including `prevHash`)

Hashing rules in current frontend implementation:

- algorithm: `keccak256`
- input encoding: UTF-8 bytes of canonical JSON payload
- canonical payload keys:
  - `version`
  - `traceId`
  - `timestamp`
  - `action`
  - `reason`
  - `operator`
  - `tokenAddress`
  - `tokenAllowed`
  - `enforcementEnabled`
  - `minSettlementAmount`
  - `txHashes`
  - `prevHash`

This enables quick integrity checks across exported history items by recomputing hashes in order.

## Suggested rollout

1. Deploy with enforcement disabled (default) and set desired `minSettlementAmount`.
2. Populate token allowlist for target stablecoins.
3. Enable `stableTokenEnforcementEnabled`.
4. Use frontend refresh + health check to verify profile status.
5. Validate evidence export includes stable settlement fields.

## Validation commands (operator quick checks)

Local tests:

```bash
forge test --match-path "contracts/test/NonCustodialAgentPayment.t.sol" -vv
```

Frontend:

```bash
python3 -m http.server 8790
```

Open:

```text
http://127.0.0.1:8790/examples/v01-metamask-settlement.html
```

Manual verification checklist:

1. Connect wallet.
2. Apply stable profile with enforcement off and min amount set.
3. Set stable token rule for target token.
4. Enable enforcement and refresh stable profile.
5. Run health check and confirm `stable_settlement` diagnostics appear.
6. Export JSON and verify stable fields exist in `authSnapshot`, `requestSnapshot`, and `riskSnapshot`.

## Known limitations in M2.0

- token-level rules are global (owner-managed), not per-buyer profile yet
- no decimal-aware floor normalization yet (raw base units only)
- no multi-chain token profile registry yet
