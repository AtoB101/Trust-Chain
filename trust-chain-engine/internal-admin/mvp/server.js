#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const http = require("http");
const { URL } = require("url");
const { ethers } = require("ethers");

const HOST = process.env.MVP_HOST || process.env.HOST || "127.0.0.1";
const PORT = Number(process.env.MVP_PORT || process.env.PORT || 8822);
const RPC_URL = process.env.RPC_URL || "";
const USER_PRIVATE_KEY = process.env.USER_PRIVATE_KEY || process.env.SETTLEMENT_PRIVATE_KEY || "";
const PROVIDER_WALLET = process.env.PROVIDER_WALLET || process.env.TREASURY_ADDRESS || "";
const CHARGE_WEI = process.env.CHARGE_WEI || "10000000000000"; // 0.00001 ETH
const LOG_PATH = process.env.LOG_PATH || path.join(__dirname, "logs", "paid-calls.jsonl");

function requireEnv() {
  const missing = [];
  if (!RPC_URL) missing.push("RPC_URL");
  if (!USER_PRIVATE_KEY) missing.push("USER_PRIVATE_KEY");
  if (!PROVIDER_WALLET) missing.push("PROVIDER_WALLET");
  if (missing.length > 0) {
    throw new Error(`Missing required env: ${missing.join(", ")}`);
  }
}

function json(res, status, payload) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload, null, 2));
}

function appendLog(record) {
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, `${JSON.stringify(record)}\n`, "utf-8");
}

function serveStaticIndex(res) {
  const p = path.join(__dirname, "public", "index.html");
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(fs.readFileSync(p, "utf-8"));
}

async function fetchBtcPriceUsd() {
  const url = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd";
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Price API failed: ${resp.status}`);
  const obj = await resp.json();
  const price = obj?.bitcoin?.usd;
  if (typeof price !== "number") throw new Error("Invalid BTC price response");
  return price;
}

async function runPaidCall(provider, wallet) {
  const callId = `call_${Date.now()}`;
  const startedAt = new Date().toISOString();
  const amount = BigInt(CHARGE_WEI);

  const userBalanceBefore = await provider.getBalance(wallet.address);
  const providerBalanceBefore = await provider.getBalance(PROVIDER_WALLET);
  const btcPriceUsd = await fetchBtcPriceUsd();

  const tx = await wallet.sendTransaction({
    to: PROVIDER_WALLET,
    value: amount,
  });
  const receipt = await tx.wait(1);

  const userBalanceAfter = await provider.getBalance(wallet.address);
  const providerBalanceAfter = await provider.getBalance(PROVIDER_WALLET);
  const completedAt = new Date().toISOString();

  const result = {
    schemaVersion: "trustchain.mvp.paid-call.v1",
    callId,
    startedAt,
    completedAt,
    btcPriceUsd,
    chargedWei: amount.toString(),
    txHash: receipt.hash,
    chainId: Number(receipt.chainId),
    blockNumber: receipt.blockNumber,
    balances: {
      user: {
        beforeWei: userBalanceBefore.toString(),
        afterWei: userBalanceAfter.toString(),
      },
      provider: {
        beforeWei: providerBalanceBefore.toString(),
        afterWei: providerBalanceAfter.toString(),
      },
    },
  };
  appendLog(result);
  return result;
}

async function main() {
  requireEnv();
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(USER_PRIVATE_KEY, provider);

  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url || "/", `http://${req.headers.host}`);
      if (req.method === "GET" && url.pathname === "/") {
        serveStaticIndex(res);
        return;
      }

      if (req.method === "GET" && (url.pathname === "/api/status" || url.pathname === "/api/health")) {
        const network = await provider.getNetwork();
        json(res, 200, {
          ok: true,
          schemaVersion: "trustchain.mvp.status.v1",
          network: {
            chainId: Number(network.chainId),
          },
          userWallet: wallet.address,
          providerWallet: PROVIDER_WALLET,
          chargeWei: CHARGE_WEI,
        });
        return;
      }

      if (req.method === "POST" && url.pathname === "/api/btc-price-paid") {
        const output = await runPaidCall(provider, wallet);
        json(res, 200, output);
        return;
      }

      json(res, 404, { error: "Not found" });
    } catch (err) {
      json(res, 500, {
        error: String(err.message || err),
      });
    }
  });

  server.listen(PORT, HOST, () => {
    console.log(`MVP server listening on http://${HOST}:${PORT}`);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
