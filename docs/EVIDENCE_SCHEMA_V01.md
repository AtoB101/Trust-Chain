# TrustChain Evidence Schema v0.1 (Frozen for M1)

This document defines the **field contract** for exported diagnosis JSON in M1.
The goal is to keep support/audit parsers stable while M2 adds new fields.

## Schema freeze policy (M1)

- `evidenceVersion = "evidence-v1"` is the canonical schema marker.
- Existing field names below are frozen for M1 and must not be renamed.
- New optional fields may be appended in M2+, but existing fields must remain backward compatible.
- `reportVersion` is legacy and transitional (`"1.1"` in current exporter); consumers should key on `evidenceVersion`.

## Top-level fields

- `reportVersion` (legacy compatibility)
- `evidenceVersion` (canonical schema marker)
- `traceId`
- `app`
- `exportedAt`
- `userAgent`
- `pageUrl`
- `network`
- `walletAddress`
- `kpis`
- `autoMonitor`
- `authSnapshot`
- `requestSnapshot`
- `executionSnapshot`
- `riskSnapshot`

## authSnapshot

- `walletAddress`
- `signaturePresent`
- `quotePresent`
- `stableSettlementSnapshot` (string snapshot shown in UI; optional in M1, expected in M2.1+)
- `stableConfigVersion` (current local stable config history version counter; expected in M2.3+)
- `latestStableChangeReason` (latest stable config change reason; nullable, expected in M2.3+)
- `latestStableOperator` (latest stable config operator label; nullable, expected in M2.3+)
- `stableConfigHistory[]` (stable settlement config change log; expected in M2.2+)
  - `version` (monotonic integer, starts from 1 in current session)
  - `prevHash` (hash pointer to previous history item hash; genesis uses `0x0`)
  - `currentHash` (hash of canonicalized current history item)
  - `traceId`
  - `timestamp`
  - `action` (`apply_profile | set_token_rule`)
  - `reason` (operator-provided reason text; expected in M2.3+)
  - `operator` (operator label; expected in M2.3+)
  - `tokenAddress` (nullable)
  - `tokenAllowed` (nullable boolean)
  - `enforcementEnabled` (optional boolean)
  - `minSettlementAmount` (optional string)
  - `txHashes` (object with tx hash fields present for the performed action)

## requestSnapshot

- `form`:
  - `engineAddress`
  - `nonCustodialAddress`
  - `tokenAddress`
  - `payeeAddress`
  - `amount`
  - `scopeText`
  - `proofHashText`
  - `ttlSeconds`
- `logFilters`:
  - `kind`
  - `severity`
- `policySnapshot` (string snapshot shown in UI)
- `policyDecision`:
  - `result` (`allowed | blocked | unknown`)
  - `reasonKind`
  - `reasonTitle`
  - `detail`
  - `decidedAt`
- `stableSettlementSnapshot` (string snapshot shown in UI)
- `stableSettlementDecision`:
  - `result` (`allowed | blocked | unknown`)
  - `reasonKind`
  - `reasonTitle`
  - `detail`
  - `decidedAt`

## executionSnapshot

- `diagnostics[]`:
  - `id`
  - `traceId`
  - `timestamp`
  - `kind`
  - `severity`
  - `title`
  - `detail`
  - `payload`
- `transactionHistory[]`:
  - `traceId`
  - `timestamp`
  - `status`
  - `txHash`
  - `blockNumber`
  - `amount`
- `lastQuote`:
  - `quoteId`
  - `payer`
  - `payee`
  - `token`
  - `amount`
  - `nonce`
  - `deadline`
  - `scopeHash`

## riskSnapshot

- `summary.totalDiagnostics`
- `summary.high`
- `summary.medium`
- `summary.low`
- `latestHighRiskTitle`
- `latestStableRiskTitle`
- `stableConfigChanges` (count of stable config changes captured in current evidence)
- `latestStableConfigVersion` (latest stable config history version; nullable)
- `stableConfigChainHead` (latest stable history `currentHash`; nullable)
- `stableSettlement`:
  - `enforcementEnabled` (nullable boolean)
  - `minSettlementAmount` (nullable string)
  - `tokenRuleResult` (nullable boolean)
  - `latestStableDecision` (`allowed | blocked | unknown`)
