# 技术部 A — Karma 公开侧执行清单（对照 SECURITY_UPGRADE_PLAN）

**仓库**: [AtoB101/Karma](https://github.com/AtoB101/Karma)（public）  
**私有侧 BillManager / LockPool**: 在 [AtoB101/Karma2](https://github.com/AtoB101/Karma2) 跟踪（本清单仅列公开侧责任边界）

---

## A1-1 全部 admin → Gnosis Safe（重新部署）

| 合约（公开栈） | 说明 |
|----------------|------|
| `SettlementEngine` | `admin` 为 `immutable`，**仅能通过新部署**改为 Safe |
| `CircuitBreaker` | 同上 |
| `NonCustodialAgentPayment` | `owner` / `arbitrator` 为 `immutable`，**仅能通过新部署**改为 Safe 或 Safe 控制的仲裁角色 |

**公开侧交付物**: Sepolia / 主网部署脚本与参数表（多签地址、角色矩阵）、部署后 `cast call` 验收记录。

---

## A1-2 CircuitBreaker 阈值在「私有侧 BillManager」强制执行

**不在本仓库**：`BillManager` 由 **Karma2** 技术部在 `createBill`（或等价入口）调用 `CircuitBreaker.humanApprovalThreshold` 并 `revert`。

**公开侧配合**: 确保 `CircuitBreaker` 部署地址与 ABI 写入 Karma2 的 `deployment-manifest.json` / 引擎配置；联调用例在 Karma2 CI 或联合预演中执行。

---

## A1-3 Solidity 0.8.28 + optimizer_runs 1000 + 常量选择器

| 项 | 状态 |
|----|------|
| 根目录 `foundry.toml` | `solc_version = "0.8.28"`, `optimizer_runs = 1000`, `src = karma-core/contracts` |
| `NonCustodialAgentPayment` `transferFrom` 选择器 | 常量 `TRANSFER_FROM_SELECTOR = 0x23b872dd` |
| `split-release/sync-templates/engine-core-devops/foundry.toml` | 与公开合约编译档位对齐的**模板**（供同步包；完整引擎在私有仓） |

**验收**: `forge build` + `forge test` 全绿；`forge snapshot --diff` 在 CI 中与 `.gas-snapshot` 对齐。

**同步到 Karma2**: 运行 `./split-release/prepare-karma2-sync-package.sh` 后，将包内 `vendor/karma-public-sync/` 一并复制到私有仓（与 `ops/release-sync/` 同级或置于其下），便于私有侧本地编译与对照；该目录为**只读快照**，真源仍以公开 `Karma` 为准。

---

## A2 CI 加固

| 门禁 | 位置 |
|------|------|
| Invariant（NC） | `.github/workflows/forge-ci.yml`、`security-ci.yml`：`NonCustodialAgentPayment.invariant.t.sol` |
| Gas diff | 同上：`forge snapshot --diff`（依赖仓库内已提交的 `.gas-snapshot`） |
| Slither | `security-ci.yml` + `scripts/slither-gate.sh`（与 `SECURITY_ACCEPTANCE_NOTES` 书面接受策略一致） |
| 跨仓锁步 | Karma2：`CORE_VERSION.lock` + `deployment-manifest.json` + `verify-manifest` + `lockstep-sync-check` workflow |

**说明**: 「Slither 零告警」与当前 `SettlementEngine` 残余项是否一致，由**验收方与 SECURITY_ACCEPTANCE_NOTES 签字**共同定义；CI 以 `slither-gate.sh` 行为为准。

---

## Sepolia 联合预演

1. Karma 发布冻结 tag + 合约地址写入 manifest。  
2. Karma2 更新 lock + manifest 并 `verify-manifest` 通过。  
3. 端到端：创建账单 / 确认 / 结算或过期 / 仲裁路径 + 监控事件抽样。  
4. 归档：交易哈希、bytecode hash、`forge test` / CI 链接。
