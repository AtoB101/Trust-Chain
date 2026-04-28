# Trust-Chain P0 Paid BTC API MVP (Private)

Goal: prove real paid API settlement with one call.

## What this MVP shows

1. User balance before call
2. Agent triggers BTC price API call
3. API returns BTC price
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
- `POST /api/btc-price-paid`

## Output logs

Paid call records are appended to:

- `logs/paid-calls.jsonl`

Each record includes:

- `btcPriceUsd`
- `chargedWei`
- `txHash`
- `balances.before/after`

## Important

- This is a private validation MVP.
- Do not use production private keys.
