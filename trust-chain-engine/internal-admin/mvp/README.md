# Trust-Chain P0 Paid BTC API MVP (Private)

Goal: prove real paid API settlement with one call.

## What this MVP shows

1. User balance before call
2. Agent triggers symbol price API call (e.g. BTCUSDT / ETHUSDC)
3. API returns symbol price
4. Automatic on-chain transfer settlement
5. Transaction hash and balances after call

## Setup

```bash
cd trust-chain-engine/internal-admin/mvp
cp .env.example .env
```

Edit `.env`:

- `RPC_URL`: your EVM RPC endpoint
- `USER_PRIVATE_KEY`: payer wallet private key (test wallet only)
- `PROVIDER_WALLET`: payee wallet address
- `CHARGE_WEI`: charge amount in wei (must be > 0)
- `MVP_PORT` (optional): default `8822`

## Run

```bash
npm install
./run-demo.sh
```

Open:

- `http://127.0.0.1:8822/`

## API

- `GET /api/health`
- `GET /api/status`
- `POST /api/price-paid` with body `{ "symbol": "BTCUSDT" }`
- `POST /api/price-paid` with body `{ "symbol": "ETHUSDC" }`
- Compatibility alias: `POST /api/btc-price-paid` (maps to BTCUSDT)

## Agent wrapTool (author monetization)

Use the private helper to wrap any tool and charge per invocation:

```javascript
const { wrapTool } = require("./trustchain-wrap-tool");

const wrapped = wrapTool({
  gatewayBaseUrl: "http://127.0.0.1:8822",
  userId: "agent-owner-01",
  price: "0.01",
  token: "USDC",
  tool: async ({ symbol }) => ({ symbol }),
  symbolResolver: (input) => input.symbol,
});
```

Run the demo:

```bash
npm run agent-example
# with custom symbol
npm run agent-example -- SOLUSDT
```

## External user simulation

```bash
npm run simulate
# writes logs/external-user-call-summary.json
```

## Capture demo proof bundle

```bash
npm run proof
# writes logs/demo-proof-<timestamp>.json
```

## Simulate external user first paid call

Run one paid call from an "external user" wallet context and print a concise summary:

```bash
npm run simulate
```

Or with explicit environment overrides:

```bash
RPC_URL=http://127.0.0.1:8545 \
USER_PRIVATE_KEY=<external-user-test-key> \
PROVIDER_WALLET=<provider-wallet> \
CHARGE_WEI=1000000000000 \
./simulate-external-user-call.sh
```

## Output logs

Paid call records are appended to:

- `logs/paid-calls.jsonl`

Each record includes:

- `symbol`
- `exchange`
- `quote`
- `chargedWei`
- `txHash`
- `balances.before/after`

## Verify first paid call closure

Run:

```bash
./verify-first-paid-call.sh
```

or:

```bash
npm run verify
```

Verifier checks:

1. a paid-call log exists
2. `chargedWei > 0`
3. `txHash` format is valid
4. user/provider balances changed in expected direction

Optional explicit threshold:

```bash
EXPECTED_MIN_CHARGE_WEI=10000000000000 ./verify-first-paid-call.sh
```

## External user simulation

```bash
npm run simulate
```

Optional symbol:

```bash
./simulate-external-user-call.sh --symbol ETHUSDC
```

## Demo proof capture

```bash
npm run proof
```

## Important

- This is a private validation MVP.
- Do not use production private keys.
