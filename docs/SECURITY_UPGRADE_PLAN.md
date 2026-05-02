# Karma 安全升级与上线方案（SECURITY_UPGRADE_PLAN）

**文档性质**：技术部执行清单 + 验收方逐项签字表  
**适用范围**：`karma-core`（公开合约与接口）、与 `Karma2`（私有引擎/运维）的联动发布  
**验收方**：按你方流程由指定负责人逐项勾选验收

---

## 0. 与当前仓库的对照说明（技术部必读）

本方案中的 **P0/P1 条目** 需与**当前主干实际代码**对齐后再关闭。下表为截至文档编写时、对 `karma-core/contracts` 的**静态对照**（技术部修完后应更新「证据」列：PR 链接、commit、测试命令输出）。

| 方案项 | 当前主干参考状态 | 证据 / 待补 |
|--------|------------------|-------------|
| P0 编译错误 | 以 CI `forge build` 为准 | PR + `forge build` 绿 |
| P0 gas 上限（批量结算） | `NonCustodialAgentPayment` 存在 `MAX_BATCH_SETTLE_SIZE`；`SettlementEngine.settleBatch` **未见**单独 `length` 上限常量 | 若方案要求 **SettlementEngine** 上限，需补 `MAX_BATCH_SIZE` + 测试 |
| P0 重入保护 | `SettlementEngine`：`submitSettlement` / `settleBatch` + `nonReentrant`；`NonCustodialAgentPayment`：关键路径含 `nonReentrant` | 见下文代码锚点 |
| P1 `expireBill` | 已实现：`Pending`/`Confirmed`、超时后释放 | 见代码锚点 |
| P1 多签 / 阈值 / timelock | **链上仍为 `immutable admin/owner`**，需产品决策与迁移方案 | 部署与治理任务，非仅文档 |

---

## 1. P0 — 阻塞级（上线前必须关闭）

### P0-1 编译错误清零

- **目标**：`forge build` 与 CI 中所有 Solidity 相关 job 零错误。
- **验收**：`forge build`；`forge test`（或 CI 等价矩阵）全绿。
- **技术部回传**：失败时的 `forge build` 完整日志 + 修复 PR。

### P0-2 Gas / 批量上限（防 DoS）

- **目标**：对批量外部调用路径设置明确上限，避免单 tx 过大导致 OOG 或滥用。
- **当前代码要点**：
  - `NonCustodialAgentPayment`：`MAX_BATCH_SETTLE_SIZE` + `settleBatch` 内对 `maxBills` 截断（见下「代码锚点」）。
  - `SettlementEngine`：`settleBatch` 为循环 `_submitSettlement`；若方案要求此处上限，**须新增常量并在循环前 `revert`**，并补充 `forge test`。
- **验收**：单测覆盖「超限 revert」；可选：fork 上估算 gas 边界。

### P0-3 重入与外部调用安全

- **目标**：资金路径上的 `transfer`/`transferFrom` 与可重入 token 组合下，不因重入破坏会计不变式。
- **当前代码要点**：`SettlementEngine` 结算路径带 `nonReentrant`；`NonCustodialAgentPayment` 在 `requestBillPayout`、仲裁结算等带 `nonReentrant`（`expireBill` 为设计上的非重入敏感路径，若方案要求可再评估是否加 guard）。
- **验收**：现有重入相关测试全绿；若有新路径，补 Foundry 用例。

#### P0 代码锚点（供 diff 与验收对齐）

```42:60:karma-core/contracts/core/SettlementEngine.sol
    function submitSettlement(QuoteTypes.Quote calldata quote, uint8 v, bytes32 r, bytes32 s) external override nonReentrant {
        _submitSettlement(quote, v, r, s);
    }

    function settleBatch(
        QuoteTypes.Quote[] calldata quotes,
        uint8[] calldata vs,
        bytes32[] calldata rs,
        bytes32[] calldata ss
    ) external override nonReentrant {
        uint256 length = quotes.length;
        if (length == 0 || length != vs.length || length != rs.length || length != ss.length) {
            revert Errors.InvalidBatchInput();
        }

        for (uint256 i = 0; i < length; ++i) {
            _submitSettlement(quotes[i], vs[i], rs[i], ss[i]);
        }
    }
```

```43:49:karma-core/contracts/core/NonCustodialAgentPayment.sol
    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_BATCH_SETTLE_SIZE = 200;
```

```330:368:karma-core/contracts/core/NonCustodialAgentPayment.sol
    function requestBillPayout(uint256 billId) external override nonReentrant returns (bool ok) {
        // ...
    }

    function expireBill(uint256 billId) external override {
        Bill storage b = bills[billId];
        if (b.billId == 0) revert BillNotFound(billId);
        if (b.status != BillStatus.Pending && b.status != BillStatus.Confirmed) {
            revert InvalidState();
        }
        if (block.timestamp <= b.deadline) revert InvalidState();
        _releaseOnCancelOrExpire(b);
        b.status = BillStatus.Expired;
        // ...
        emit BillExpired(billId);
    }
```

**技术部须在 PR 描述中粘贴**：与上表不一致时的**具体 unified diff**（每项 P0 一条 PR 或合并说明）。

---

## 2. P1 — 上线前必须（治理与资金安全）

### P1-1 管理员 / Owner 多签（Gnosis Safe 或等效）

- **目标**：生产环境部署的 `SettlementEngine.admin`、`NonCustodialAgentPayment.owner`（及仲裁相关角色）为**多签地址**，非 EOA。
- **验收**：链上 `admin`/`owner` 指向 Safe；Safe policy（阈值、成员）记录在运维台账。

### P1-2 阈值执行 + Timelock（敏感操作）

- **目标**：改参数、暂停、升级实现等路径具备**延迟 + 多签阈值**（具体列表与合约接口由架构定稿）。
- **验收**：测试网演练一次「提案 → timelock → 执行」；主网参数表与角色表一致。

### P1-3 `expireBill` 与超时释放（业务 + 安全）

- **目标**：超时账单可释放占用，避免资金/额度逻辑冻结；行为与监控一致。
- **当前代码**：已实现（见上锚点）。
- **验收**：集成测试覆盖 Pending/Confirmed 超时；监控对 `BillExpired` 有告警或仪表盘。

---

## 3. P2 — 上线后加固（可排期）

- **编译器 / 优化器**：固定 `solc` 版本与 `optimizer_runs`；变更需重新跑全量测试与 Slither。
- **合约版本与存储布局**：升级策略（透明代理/UUPS 等）与存储 gap 文档化。
- **Selector / 路由优化**：减少误调用面；与 OpenAPI/前端路由对齐（见 `openapi/karma-v1.yaml`）。

---

## 4. CI/CD、静态分析、部署与监控

| 域 | 要求 | 仓库参考 |
|----|------|----------|
| CI | PR 必过：`forge test`、安全门禁、可见性门禁 | `.github/workflows/forge-ci.yml`、`security-ci.yml`、`security-baseline-guard.yml`、`visibility-guard.yml` |
| 静态分析 | Slither 等；残余须有 `docs/SECURITY_ACCEPTANCE_NOTES.md` 类书面接受项 | 与 `scripts/slither-gate.sh` 策略一致 |
| 部署 | 双仓 `CORE_VERSION.lock` + `deployment-manifest.json` + `verify-manifest`；Karma2 防漂移 workflow | `split-release/`、`ops/release-sync/`（Karma2） |
| 监控告警 | Owner 变更、异常 revert 率、结算失败分类 | 运维 runbook |
| L0–L3 应急 SOP | 分级响应、回滚、沟通模板 | 技术部在私有仓维护最新版 runbook |

---

## 5. 上线前最终检查表（28 项）

验收方逐项勾选（`[ ]` 未完成，`[x]` 已完成）。

### 合约与测试（8）

- [ ] `forge build` 无错误、无未处理 warning 策略已约定
- [ ] `forge test` 全量通过（含不变式/重入相关用例）
- [ ] 批量路径 gas 上限与单测已合并（含 SettlementEngine 若适用）
- [ ] `expireBill` / 超时路径行为与文档一致
- [ ] EIP-712 域、链 ID、合约地址与前端/OpenAPI 一致
- [ ] 任意 `transferFrom` 路径已审计（签名/nonce/白名单）
- [ ] 暂停/熔断策略与运维一致
- [ ] 升级/不可升级策略已书面确认

### 治理与密钥（6）

- [ ] 生产 `admin`/`owner` 为多签
- [ ] Timelock 与阈值配置已记录
- [ ] 无私钥进仓库；`.env` 仅占位
- [ ] RPC / API 密钥在密钥管理器中轮换策略明确
- [ ] 部署账户与日常运维账户分离
- [ ] 事故时可紧急暂停的责任人已备案

### 双仓联动（6）

- [ ] `Karma` 发布 tag / commit 已冻结
- [ ] `Karma2` `CORE_VERSION.lock` 与 manifest 一致且 `verify-manifest` 通过
- [ ] `openapi/karma-v1.yaml` 版本与部署一致
- [ ] 接口 ABI/地址已同步到引擎侧配置
- [ ] Karma2 必跑 CI（lockstep）已启用且为 required check
- [ ] 回滚 manifest 已准备上一版本

### 监控与应急（5）

- [ ] 主网/测试网关键事件订阅正常
- [ ] Owner / 角色变更告警已配置
- [ ] L1/L2 值班与升级窗口已排期
- [ ] L3 重大事故升级路径与对外话术已批准
- [ ] 演练记录已归档

### 法务与对外（3）

- [ ] 对外披露范围与白皮书/站点一致
- [ ] 第三方依赖许可证审查完成
- [ ] 用户条款/风险披露已更新（如适用）

---

## 6. 技术部完成后的回传模板（复制到 PR 或邮件）

```
SECURITY_UPGRADE_PLAN 执行结果

P0:
- [ ] 编译：PR #___ forge build 绿
- [ ] Gas 上限：PR #___ 说明文件：SettlementEngine / NonCustodialAgentPayment
- [ ] 重入：PR #___ 测试：___

P1:
- [ ] 多签：Safe 地址 ___ 网络 ___
- [ ] Timelock：配置摘要 ___
- [ ] expireBill：已验收场景 ___

P2：排期链接 ___

28 项检查表：附件或 wiki 链接 ___

验收负责人：___ 日期：___
```

---

## 7. 文档维护

- 技术部每完成一项 P0/P1，应更新本节「与当前仓库的对照表」中的 **证据** 列。
- 若方案与实现有偏差，以**经批准的变更说明**为准，并同步更新 `docs/SECURITY_ACCEPTANCE_NOTES.md`（如适用）。
