# Security Acceptance Notes (Pre-Go-Live)

This document records security findings that are explicitly accepted for go-live,
including rationale, active mitigations, and post-launch monitoring actions.

## Current Accepted Item

### SA-001: `calls-loop` in `SettlementEngine.settleBatch`

- **Source**: Slither detector `calls-loop`
- **Location**: `karma-core/contracts/core/SettlementEngine.sol`
- **Finding summary**: `settleBatch` iterates and `_submitSettlement` performs
  `IERC20.transferFrom`, which is an external call inside a loop.

#### Decision

- **Status**: Accepted for launch
- **Risk class**: Design-level operational risk (not a direct fund-loss critical)
- **Reason**: Batch settlement is a required product capability.

#### Existing Mitigations

1. **Reentrancy guard** (`nonReentrant`) on settlement entry points.
2. **Strict signature validation** for each quote (`recoverStrict`).
3. **Replay prevention** via nonce and `executedQuotes`.
4. **Batch-size cap** (`MAX_BATCH_SIZE`) to limit gas/DoS blast radius.
5. **Input validation** on token allowlist, payer/payee, amount, and deadline.

#### Residual Risk

- Large or pathological token behavior can still increase batch execution
  volatility (latency/gas/failure rate), even with max batch limits.

#### Monitoring Requirements

Post-launch, track and alert on:

- batch settlement failure rate
- average and p95 gas per batch
- repeated failures by token address
- repeated failures by caller account

#### Next Improvement (Planned)

- Make batch-size limit policy-driven/configurable per environment.
- Add per-token safety profile and dynamic throttling for unstable tokens.

---

## Approval Record

- **Prepared by**: Karma engineering agent
- **Basis**: latest static-analysis gate output + contract regression suite
- **Date**: 2026-04-30

