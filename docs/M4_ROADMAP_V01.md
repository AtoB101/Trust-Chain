# M4 Roadmap v0.1 (Productionization and Interop)

This document formalizes M4 after M3 completion.
Goal: evolve TrustChain proof/evidence flow from "operationally usable" to "production-grade and machine-enforceable."

## M4 scope

- Standardize evidence schema version signaling and compatibility checks.
- Add CI-friendly machine validators for diagnosis exports.
- Improve long-run operations readiness for proof verification pipelines.

## M4 phases

### M4.0 — Evidence schema compatibility baseline

Deliverables:

1. Exported diagnosis JSON carries stable schema marker:
   - `schemaVersion = "evidence-v1"` (canonical)
   - `evidenceVersion = "evidence-v1"` (legacy compatibility alias)
2. Add machine validator script:
   - `scripts/validate-evidence-schema.sh`
   - validates required top-level sections and key nested fields
   - supports text/json output and non-zero exit on incompatibility
3. Add command entry:
   - `make validate-evidence-schema`
4. Update docs:
   - `docs/EVIDENCE_SCHEMA_V01.md`
   - `docs/COMMANDS.md`

Acceptance:
- validator returns PASS for current exporter output
- validator returns FAIL when required schema marker/sections are missing

### M4.1 — CI gate for evidence compatibility

Target:
- provide a CI recipe (or script wrapper) that fails PR checks when exported diagnosis JSON violates schema compatibility.

Planned deliverables:
- reproducible validation command template for CI runners
- failure reason mapping for quick triage
- docs section for GitHub Actions / local pre-merge checks

### M4.2 — Ops-grade patrol profile

Target:
- convert existing batch proof checks into scheduled patrol policy profiles.

Planned deliverables:
- recommended policy bundles (strict/min-total/recent-pass/max-fail)
- alert-friendly JSON report contract and examples
- operator playbook for handling patrol failures

## Notes

- M4.0 focuses on backward compatibility and machine readability, minimizing break risk.
- M4.1 and M4.2 build on existing M3 scripts and reports instead of replacing them.
