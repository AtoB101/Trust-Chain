// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {KYARegistry} from "../core/KYARegistry.sol";
import {LockPoolManager} from "../core/LockPoolManager.sol";
import {CircuitBreaker} from "../core/CircuitBreaker.sol";
import {BillManager} from "../core/BillManager.sol";
import {AuthTokenManager} from "../core/AuthTokenManager.sol";
import {Types} from "../libraries/Types.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {AuthTestHelper} from "./helpers/AuthTestHelper.sol";

contract CrossModuleHandler is AuthTestHelper {
    KYARegistry internal registry;
    LockPoolManager internal pool;
    BillManager internal bill;
    AuthTokenManager internal auth;
    MockERC20 internal token;

    uint256[] internal ownerPks;
    uint256[] internal agentPks;
    address[] internal owners;
    address[] internal agents;
    bytes32[] internal poolIds;
    uint256[] internal billIds;

    constructor(
        KYARegistry _registry,
        LockPoolManager _pool,
        BillManager _bill,
        AuthTokenManager _auth,
        MockERC20 _token
    ) {
        registry = _registry;
        pool = _pool;
        bill = _bill;
        auth = _auth;
        token = _token;

        ownerPks.push(0xAA01);
        ownerPks.push(0xAA02);
        ownerPks.push(0xAA03);
        agentPks.push(0xBB01);
        agentPks.push(0xBB02);
        agentPks.push(0xBB03);

        owners.push(vm.addr(ownerPks[0]));
        owners.push(vm.addr(ownerPks[1]));
        owners.push(vm.addr(ownerPks[2]));

        agents.push(vm.addr(agentPks[0]));
        agents.push(vm.addr(agentPks[1]));
        agents.push(vm.addr(agentPks[2]));

        for (uint256 i = 0; i < owners.length; i++) {
            vm.deal(owners[i], 10 ether);
            vm.prank(owners[i]);
            registry.registerDID{value: 0.01 ether}(agents[i], keccak256(abi.encodePacked("payer", i)), 365);
            vm.deal(agents[i], 10 ether);
            token.mint(owners[i], 10_000_000);
            vm.prank(owners[i]);
            token.approve(address(pool), type(uint256).max);
        }
    }

    function createPool(uint256 ownerSeed, uint256 amountSeed) external {
        address owner = owners[ownerSeed % owners.length];
        address agent = agents[ownerSeed % agents.length];
        uint256 amount = bound(amountSeed, 1, 20_000);
        vm.prank(owner);
        bytes32 poolId = pool.createLockPool(agent, address(token), amount);
        poolIds.push(poolId);
    }

    function createBill(uint256 poolSeed, uint256 toSeed, uint256 amountSeed) external {
        if (poolIds.length == 0) return;
        bytes32 poolId = poolIds[poolSeed % poolIds.length];
        (, , address fromAgent, , , , , , ,) = pool.pools(poolId);
        address toAgent = agents[toSeed % agents.length];
        if (toAgent == fromAgent) {
            toAgent = agents[(toSeed + 1) % agents.length];
        }

        uint256 mappingBalance = pool.getMappingBalance(poolId);
        if (mappingBalance == 0) return;

        uint256 amount = bound(amountSeed, 1, mappingBalance);
        vm.prank(fromAgent);
        uint256 fromAgentPk = _pkForAgent(fromAgent);
        (bytes32 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            issueAndSignAuth(auth, fromAgentPk, fromAgent, Types.OperationType.CreateBill, amount);
        uint256 createdBillId =
            bill.createBill(poolId, toAgent, amount, "service", "ipfs://proof", tokenId, deadline, v, r, s);
        billIds.push(createdBillId);
    }

    function confirmBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 targetBillId = billIds[billSeed % billIds.length];
        (,,,,,,, Types.BillStatus status,,) = bill.bills(targetBillId);
        if (status != Types.BillStatus.Pending) return;
        bytes32 poolId = bill.billPoolId(targetBillId);
        address poolOwner = pool.getPoolOwner(poolId);
        uint256 ownerPk = _pkForOwner(poolOwner);
        (, , , , uint256 amount, , , , ,) = bill.bills(targetBillId);
        (bytes32 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            issueAndSignAuth(auth, ownerPk, poolOwner, Types.OperationType.ConfirmBill, amount);
        vm.prank(poolOwner);
        bill.confirmBill(targetBillId, tokenId, deadline, v, r, s);
    }

    function cancelBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 targetBillId = billIds[billSeed % billIds.length];
        (,,,,,,, Types.BillStatus status,,) = bill.bills(targetBillId);
        if (status != Types.BillStatus.Pending) return;
        bytes32 poolId = bill.billPoolId(targetBillId);
        address poolOwner = pool.getPoolOwner(poolId);
        uint256 ownerPk = _pkForOwner(poolOwner);
        (, , , , uint256 amount, , , , ,) = bill.bills(targetBillId);
        (bytes32 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            issueAndSignAuth(auth, ownerPk, poolOwner, Types.OperationType.CancelBill, amount);
        vm.prank(poolOwner);
        bill.cancelBill(targetBillId, tokenId, deadline, v, r, s);
    }

    function closeBatchByBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 targetBillId = billIds[billSeed % billIds.length];
        (, uint256 batchId, , , , , , , ,) = bill.bills(targetBillId);
        if (batchId == 0) return;
        (,,,, Types.BatchStatus status,,) = bill.batches(batchId);
        if (status != Types.BatchStatus.Open) return;
        bytes32 poolId = bill.billPoolId(targetBillId);
        address poolOwner = pool.getPoolOwner(poolId);
        vm.prank(poolOwner);
        bill.closeBatch(batchId);
    }

    function settleBatchByBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 targetBillId = billIds[billSeed % billIds.length];
        (, uint256 batchId, , , , , , , ,) = bill.bills(targetBillId);
        if (batchId == 0) return;
        (,,,, Types.BatchStatus status,,) = bill.batches(batchId);
        if (status != Types.BatchStatus.Closed) return;
        bytes32 poolId = bill.billPoolId(targetBillId);
        address poolOwner = pool.getPoolOwner(poolId);
        vm.prank(poolOwner);
        bill.settleBatch(batchId);
    }

    function topUp(uint256 poolSeed, uint256 amountSeed) external {
        if (poolIds.length == 0) return;
        bytes32 poolId = poolIds[poolSeed % poolIds.length];
        (, address owner, , , , , , , ,) = pool.pools(poolId);
        uint256 amount = bound(amountSeed, 1, 10_000);
        vm.prank(owner);
        pool.topUpLockPool(poolId, amount);
    }

    function withdraw(uint256 poolSeed, uint256 amountSeed) external {
        if (poolIds.length == 0) return;
        bytes32 poolId = poolIds[poolSeed % poolIds.length];
        (
            ,
            address owner,
            ,
            ,
            uint256 totalLocked,
            uint256 mappingBalance,
            uint256 pendingAmount,
            ,
            ,
            uint256 createdAt
        ) = pool.pools(poolId);
        createdAt;
        if (pendingAmount != 0 || totalLocked == 0 || mappingBalance == 0) return;

        uint256 amount = bound(amountSeed, 1, mappingBalance);
        vm.prank(owner);
        pool.withdrawLockPool(poolId, amount);
    }

    function getPoolCount() external view returns (uint256) {
        return poolIds.length;
    }

    function getPoolIdAt(uint256 index) external view returns (bytes32) {
        return poolIds[index];
    }

    function getBillCount() external view returns (uint256) {
        return billIds.length;
    }

    function getBillIdAt(uint256 index) external view returns (uint256) {
        return billIds[index];
    }

    function _pkForOwner(address owner) internal view returns (uint256) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) return ownerPks[i];
        }
        return 0;
    }

    function _pkForAgent(address agent) internal view returns (uint256) {
        for (uint256 i = 0; i < agents.length; i++) {
            if (agents[i] == agent) return agentPks[i];
        }
        return 0;
    }

}

contract CrossModuleAccountingInvariantTest is StdInvariant, Test {
    KYARegistry internal registry;
    LockPoolManager internal pool;
    CircuitBreaker internal breaker;
    BillManager internal bill;
    AuthTokenManager internal auth;
    CrossModuleHandler internal handler;
    MockERC20 internal token;

    function setUp() public {
        registry = new KYARegistry();
        pool = new LockPoolManager(address(registry));
        breaker = new CircuitBreaker(address(this));
        auth = new AuthTokenManager();
        bill = new BillManager(address(pool), address(registry), address(breaker), address(auth));
        pool.setBillManager(address(bill));
        token = new MockERC20();

        handler = new CrossModuleHandler(registry, pool, bill, auth, token);
        targetContract(address(handler));
    }

    function invariant_PoolAccountingConservation_MultiPool() public view {
        uint256 poolCount = handler.getPoolCount();
        for (uint256 i = 0; i < poolCount; i++) {
            bytes32 poolId = handler.getPoolIdAt(i);
            (,,,, uint256 totalLocked, uint256 mappingBalance, uint256 pendingAmount, uint256 settledAmount,,) =
                pool.pools(poolId);
            settledAmount;
            assertEq(totalLocked, mappingBalance + pendingAmount, "escrow conservation broken");
        }
    }

    function invariant_BillPoolMatchesBatchPool() public view {
        uint256 billCount = handler.getBillCount();
        for (uint256 i = 0; i < billCount; i++) {
            uint256 billId = handler.getBillIdAt(i);
            (, uint256 batchId, , , , , , , ,) = bill.bills(billId);
            if (batchId == 0) continue;

            bytes32 mappedPoolId = bill.billPoolId(billId);
            (, bytes32 batchPoolId,,,,,) = bill.batches(batchId);
            assertEq(mappedPoolId, batchPoolId, "bill pool and batch pool mismatch");
        }
    }
}
