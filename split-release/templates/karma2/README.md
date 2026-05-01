# Karma2 Private Repo Alignment Kit

Copy this directory into the private repository (`Karma2`) as:

- `ops/release/CORE_VERSION.lock.example`
- `ops/release/deployment-manifest.json.example`
- `ops/release/verify-manifest.sh`

Then:

1. Copy `CORE_VERSION.lock.example` to `CORE_VERSION.lock` and fill real values.
2. Copy `deployment-manifest.json.example` to `deployment-manifest.json` and fill release data.
3. Run `./verify-manifest.sh` in the private repository root before deployment.

This keeps private engine releases pinned to one audited public core release.
