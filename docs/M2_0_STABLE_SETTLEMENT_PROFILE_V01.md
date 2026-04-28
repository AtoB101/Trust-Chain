# M2.0 Stable Settlement Profile v0.1

This profile introduces a first on-chain settlement safety baseline for stablecoin-oriented flows.

## Goals

- constrain bill creation to explicitly allowed tokens when enforcement is enabled
- prevent dust-level bill creation via minimum bill amount
- keep rollout controlled with owner-managed toggles

## Contract controls

Implemented in `NonCustodialAgentPayment`:

- `setStableSettlementEnforced(bool enforced)`
  - when enabled, `createBill` requires token allowlist approval
- `setTokenSettlementAllowed(address token, bool allowed)`
  - owner-managed token allowlist flag
- `setMinSettlementAmount(uint256 minAmount)`
  - global minimum principal amount for `createBill`

Views:

- `stableSettlementEnforced()`
- `isTokenSettlementAllowed(address token)`
- `minSettlementAmount()`

## Enforcement points

### `createBill(...)`

Now checks:

1. `amount >= minSettlementAmount`
2. if `stableSettlementEnforced == true`, then `isTokenSettlementAllowed(token) == true`

## Suggested rollout

1. Deploy with enforcement disabled (default) and set desired `minSettlementAmount`.
2. Populate token allowlist for target stablecoins.
3. Enable `stableSettlementEnforced`.
4. Monitor rejection reasons and adjust operator docs.

## Known limitations in M2.0

- token-level rules are global (owner-managed), not per-buyer profile yet
- no decimal-aware floor normalization yet (raw base units only)
- no multi-chain token profile registry yet
