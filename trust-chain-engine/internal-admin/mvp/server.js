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
const DEFAULT_SYMBOL = (process.env.DEFAULT_SYMBOL || "BTC/USDT").toUpperCase();

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

function normalizeSymbol(raw) {
  const cleaned = String(raw || DEFAULT_SYMBOL).trim().toUpperCase().replace(/\s+/g, "");
  const pairCode = cleaned.replace("/", "");
  if (!/^[A-Z0-9]{6,20}$/.test(pairCode)) {
    throw new Error(`Invalid symbol format: ${raw}`);
  }
  const display = cleaned.includes("/") ? cleaned : `${pairCode.slice(0, pairCode.length - 4)}/${pairCode.slice(-4)}`;
  return { display, pairCode };
}

function explorerUrl(chainId, txHash) {
  if (!txHash) return "";
  if (chainId === 11155111) return `https://sepolia.etherscan.io/tx/${txHash}`;
  if (chainId === 1) return `https://etherscan.io/tx/${txHash}`;
  return `https://explorer.invalid/tx/${txHash}`;
}

async function fetchPrice(symbol) {
  const parsed = normalizeSymbol(symbol);
  // Binance ticker endpoint supports a broad list of exchange pairs.
  const url = `https://api.binance.com/api/v3/ticker/price?symbol=${parsed.pairCode}`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Price API failed: ${resp.status}`);
  const obj = await resp.json();
  const price = Number(obj?.price);
  if (!Number.isFinite(price)) throw new Error("Invalid price response");
  return {
    exchange: "binance",
    symbol: parsed.display,
    pairCode: parsed.pairCode,
    price,
  };
}

async function runPaidCall(provider, wallet, symbol, userId) {
  const callId = `call_${Date.now()}`;
  const startedAt = new Date().toISOString();
  const amount = BigInt(CHARGE_WEI);

  const userBalanceBefore = await provider.getBalance(wallet.address);
  const providerBalanceBefore = await provider.getBalance(PROVIDER_WALLET);
  const quote = await fetchPrice(symbol);

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
    ok: true,
    callId,
    userId: String(userId || "external-user"),
    startedAt,
    completedAt,
    quote: {
      exchange: quote.exchange,
      symbol: quote.symbol,
      pairCode: quote.pairCode,
      price: quote.price,
    },
    chargedWei: amount.toString(),
    txHash: receipt.hash,
    chainId: Number(receipt.chainId),
    blockNumber: receipt.blockNumber,
    explorerUrl: explorerUrl(Number(receipt.chainId), receipt.hash),
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
    settlement: {
      chargedWei: amount.toString(),
      txHash: receipt.hash,
      chainId: Number(receipt.chainId),
      explorerUrl: explorerUrl(Number(receipt.chainId), receipt.hash),
      beforeBalanceWei: userBalanceBefore.toString(),
      afterBalanceWei: userBalanceAfter.toString(),
      beforeBalanceEth: ethers.formatEther(userBalanceBefore),
      afterBalanceEth: ethers.formatEther(userBalanceAfter),
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
          defaultSymbol: DEFAULT_SYMBOL,
          supportedPriceSource: "binance",
        });
        return;
      }

      if (req.method === "GET" && url.pathname === "/api/config") {
        json(res, 200, {
          ok: true,
          schemaVersion: "trustchain.mvp.config.v1",
          pricePerCallWei: CHARGE_WEI,
          pricePerCallEth: ethers.formatEther(CHARGE_WEI),
          defaultSymbol: DEFAULT_SYMBOL,
          endpoint: "/api/price-paid",
        });
        return;
      }

      if (req.method === "POST" && (url.pathname === "/api/btc-price-paid" || url.pathname === "/api/price-paid")) {
        let body = {};
        let bodyRaw = "";
        req.on("data", (chunk) => {
          bodyRaw += chunk;
        });
        await new Promise((resolve) => req.on("end", resolve));
        if (bodyRaw.trim()) {
          try {
            body = JSON.parse(bodyRaw);
          } catch (_) {
            // Keep empty body; we'll use defaults.
          }
        }
        const symbol = String(body.symbol || url.searchParams.get("symbol") || DEFAULT_SYMBOL);
        const userId = String(body.userId || "external-user");
        const output = await runPaidCall(provider, wallet, symbol, userId);
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
