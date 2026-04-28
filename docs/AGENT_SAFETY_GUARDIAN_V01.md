# Agent Safety Guardian v0.1

This document defines the full-chain "Agent Safety Guardian" workflow for internal validation, risk identification, severity tagging, and registry logging during market verification.

## 1) Goals

- Run reproducible internal self-checks before and during external validation.
- Identify and classify risks from evidence and patrol outputs.
- Persist a machine-readable risk registry for longitudinal analysis.
- Produce summary/alert artifacts to support later predictive defense models.

## 2) Entry command

```bash
./scripts/agent-safety-guardian.sh --profile balanced
```

Make shortcut:

```bash
make agent-safety-guardian
```

## 3) Execution stages

The guardian runs these stages in one flow:

1. **Preflight check** (`scripts/preflight.sh --mode local`)  
   Verifies local tool prerequisites.
2. **Evidence schema check** (`scripts/validate-evidence-schema.sh`)  
   Validates sample evidence schema compatibility.
3. **Patrol check** (`scripts/proof-patrol.sh`)  
   Executes proof-index policy gates with profile thresholds.
4. **Risk synthesis + registry append**  
   Builds:
   - run summary JSON
   - alert JSON
   - append-only risk registry (`results/agent-safety-risk-registry.json`)

## 4) Severity model

Risk levels:

- `critical`: blocking risk requiring immediate response
- `high`: significant risk, should be resolved before broad rollout
- `medium`: non-blocking but action recommended
- `low`: informational/observation

Current mapping (v0.1):

- preflight fail -> `high`
- schema validation fail -> `high`
- patrol `maxFailViolated` or `recentPassViolated` -> `critical`
- patrol `minTotalViolated` -> `high`
- patrol `strictNoMatchViolated` -> `medium`

## 5) Artifacts

By default, outputs go to `results/`:

- `agent-safety-guardian-summary-latest.json`
- `agent-safety-guardian-alert-latest.json`
- `agent-safety-risk-registry.json` (append-only array)

Each run includes:

- `runId`, `profile`, `generatedAt`
- stage outcomes
- structured `risks[]` list
- recommended `nextActions[]`

## 6) Suggested operations rhythm

- **Daily/cron**: run `balanced` profile.
- **Release gate**: run `strict` profile.
- **Cold-start period**: optionally run `lenient` while accumulating enough samples.

Example cron (UTC every hour):

```bash
0 * * * * cd /path/to/repo && ./scripts/agent-safety-guardian.sh --profile balanced --no-summary
```

## 7) Registry usage for predictive defense

`agent-safety-risk-registry.json` is intentionally stable and append-only for:

- trend analysis (risk counts over time)
- recurrence analysis by `category`/`reason`
- future anomaly detection models

Recommended next step:

- build a weekly trend report script that groups by `level/category/reason`.
