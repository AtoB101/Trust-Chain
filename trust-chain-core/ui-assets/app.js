const STORE_KEY = "trustchain_ui_p0_state_v1";

function buildSeedState() {
  return {
    buyer: {
      wallet: "0xA12...89F",
      token: "USDC",
      walletBalance: 100,
      allowance: 50,
      locked: 30,
      active: 24.5,
      reserved: 5.5,
      settled: 12.2,
      disputed: 0,
      perCallLimit: 0.05,
      dailyLimit: 5,
      autoConfirm: 0.01,
    },
    services: [{ id: "svc-001", name: "Price API", price: 0.01, token: "USDC", status: "active" }],
    bills: [
      {
        id: "BILL-001",
        service: "Price API",
        seller: "MarketDataBot",
        amount: 0.01,
        status: "Settled",
        createdAt: "2026-04-29 08:10",
      },
      {
        id: "BILL-002",
        service: "Risk Scan",
        seller: "SafeScan",
        amount: 0.03,
        status: "Pending",
        createdAt: "2026-04-29 08:21",
      },
    ],
    calls: [
      {
        time: "2026-04-29 08:21",
        agent: "Trading Agent",
        service: "Risk Scan",
        reason: "Token safety check",
        price: 0.03,
        status: "Waiting settle",
      },
    ],
    revenue: [{ time: "2026-04-29 08:10", buyer: "0xA12...89F", service: "Price API", amount: 0.01, status: "Settled" }],
  };
}

function initState() {
  const seed = buildSeedState();
  localStorage.setItem(STORE_KEY, JSON.stringify(seed));
  return seed;
}

function getState() {
  const raw = localStorage.getItem(STORE_KEY);
  if (!raw) return initState();
  try {
    return JSON.parse(raw);
  } catch {
    return initState();
  }
}

function saveState(state) {
  localStorage.setItem(STORE_KEY, JSON.stringify(state));
}

function resetDemoState() {
  return initState();
}

function maybeResetFromUrl() {
  if (typeof window === "undefined") return;
  const params = new URLSearchParams(window.location.search);
  if (params.get("demoReset") === "1") {
    resetDemoState();
  }
}

function fmt(n, token) {
  return `${Number(n).toFixed(2)} ${token}`;
}

maybeResetFromUrl();

window.tcUI = {
  getState,
  saveState,
  fmt,
  resetDemoState,
};
