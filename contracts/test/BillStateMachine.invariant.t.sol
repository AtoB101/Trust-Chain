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

contract BillStateHandler is AuthTestHelper {
    KYARegistry internal registry;
    LockPoolManager internal pool;
    BillManager internal bill;
    AuthTokenManager internal auth;
    MockERC20 internal token;

    uint256 internal ownerPk = 0xA001;
    uint256 internal payerPk = 0xA002;
    uint256 internal payeePk = 0xA003;
    address internal owner;
    address internal payerAgent;
    address internal payeeAgent;
    bytes32 internal poolId;

    uint256[] internal billIds;
    uint256[] internal seenBatchIds;
    mapping(uint256 => bool) internal isBatchSeen;

    mapping(uint256 => Types.BillStatus) internal maxBillStatusSeen;
    mapping(uint256 => Types.BatchStatus) internal maxBatchStatusSeen;

    constructor(KYARegistry _registry, LockPoolManager _pool, BillManager _bill, AuthTokenManager _auth, MockERC20 _token) {
        registry = _registry;
        pool = _pool;
        bill = _bill;
        auth = _auth;
        token = _token;
        owner = vm.addr(ownerPk);
        payerAgent = vm.addr(payerPk);
        payeeAgent = vm.addr(payeePk);

        vm.deal(owner, 10 ether);
        vm.deal(payerAgent, 10 ether);
        vm.deal(payeeAgent, 10 ether);

        vm.prank(owner);
        registry.registerDID{value: 0.01 ether}(payerAgent, keccak256("payer"), 365);
        vm.prank(payeeAgent);
        registry.registerDID{value: 0.01 ether}(payeeAgent, keccak256("payee"), 365);
        token.mint(owner, 20_000_000);
        vm.prank(owner);
        token.approve(address(pool), type(uint256).max);

        vm.prank(owner);
        poolId = pool.createLockPool(payerAgent, address(token), 20_000);
    }

    function createBill(uint256 amountSeed) external {
        uint256 mappingBalance = pool.getMappingBalance(poolId);
        if (mappingBalance == 0) return;

        uint256 amount = bound(amountSeed, 1, mappingBalance);
        vm.prank(payerAgent);
        (bytes32 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            issueAndSignAuth(auth, payerPk, payerAgent, Types.OperationType.CreateBill, amount);
        uint256 billId =
            bill.createBill(poolId, payeeAgent, amount, "service", "ipfs://proof", tokenId, deadline, v, r, s);
        billIds.push(billId);

        (, uint256 batchId, , , , , , Types.BillStatus status, ,) = bill.bills(billId);
        _trackBillStatus(billId, status);
        _trackBatch(batchId);
        _trackBatchStatus(batchId);
    }

    function confirmBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 billId = billIds[billSeed % billIds.length];
        (, uint256 batchId, , , , , , Types.BillStatus statusBefore, ,) = bill.bills(billId);
        if (statusBefore != Types.BillStatus.Pending) return;
        (, , , , uint256 amount, , , , ,) = bill.bills(billId);
        (bytes32 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            issueAndSignAuth(auth, ownerPk, owner, Types.OperationType.ConfirmBill, amount);
        vm.prank(owner);
        bill.confirmBill(billId, tokenId, deadline, v, r, s);
        (, , , , , , , Types.BillStatus statusAfter, ,) = bill.bills(billId);
        _trackBillStatus(billId, statusAfter);
        _trackBatch(batchId);
        _trackBatchStatus(batchId);
    }

    function cancelBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 billId = billIds[billSeed % billIds.length];
        (, uint256 batchId, , , , , , Types.BillStatus statusBefore, ,) = bill.bills(billId);
        if (statusBefore != Types.BillStatus.Pending) return;
        (, , , , uint256 amount, , , , ,) = bill.bills(billId);
        (bytes32 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            issueAndSignAuth(auth, ownerPk, owner, Types.OperationType.CancelBill, amount);
        vm.prank(owner);
        bill.cancelBill(billId, tokenId, deadline, v, r, s);
        (, , , , , , , Types.BillStatus statusAfter, ,) = bill.bills(billId);
        _trackBillStatus(billId, statusAfter);
        _trackBatch(batchId);
        _trackBatchStatus(batchId);
    }

    function closeBatchByBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 billId = billIds[billSeed % billIds.length];
        (, uint256 batchId, , , , , , , ,) = bill.bills(billId);
        if (batchId == 0) return;

        (,, , , Types.BatchStatus statusBefore,,) = bill.batches(batchId);
        if (statusBefore != Types.BatchStatus.Open) return;

        vm.prank(owner);
        bill.closeBatch(batchId);
        _trackBatch(batchId);
        _trackBatchStatus(batchId);
    }

    function settleBatchByBill(uint256 billSeed) external {
        if (billIds.length == 0) return;
        uint256 billId = billIds[billSeed % billIds.length];
        (, uint256 batchId, , , , , , , ,) = bill.bills(billId);
        if (batchId == 0) return;

        (,, , , Types.BatchStatus statusBefore,,) = bill.batches(batchId);
        if (statusBefore != Types.BatchStatus.Closed) return;

        vm.prank(owner);
        bill.settleBatch(batchId);
        _trackBatch(batchId);
        _trackBatchStatus(batchId);

        uint256 totalBills = billIds.length;
        for (uint256 i = 0; i < totalBills; i++) {
            uint256 candidateBillId = billIds[i];
            (, uint256 candidateBatchId, , , , , , Types.BillStatus newStatus, ,) = bill.bills(candidateBillId);
            if (candidateBatchId == batchId) {
                _trackBillStatus(candidateBillId, newStatus);
            }
        }
    }

    function _trackBatch(uint256 batchId) internal {
        if (batchId == 0 || isBatchSeen[batchId]) return;
        isBatchSeen[batchId] = true;
        seenBatchIds.push(batchId);
    }

    function _trackBillStatus(uint256 billId, Types.BillStatus status) internal {
        if (uint8(status) > uint8(maxBillStatusSeen[billId])) {
            maxBillStatusSeen[billId] = status;
        }
    }

    function _trackBatchStatus(uint256 batchId) internal {
        if (batchId == 0) return;
        (,, , , Types.BatchStatus status,,) = bill.batches(batchId);
        if (uint8(status) > uint8(maxBatchStatusSeen[batchId])) {
            maxBatchStatusSeen[batchId] = status;
        }
    }

    function getBillCount() external view returns (uint256) {
        return billIds.length;
    }

    function getBillIdAt(uint256 index) external view returns (uint256) {
        return billIds[index];
    }

    function getMaxBillStatusSeen(uint256 billId) external view returns (Types.BillStatus) {
        return maxBillStatusSeen[billId];
    }

    function getSeenBatchCount() external view returns (uint256) {
        return seenBatchIds.length;
    }

    function getSeenBatchIdAt(uint256 index) external view returns (uint256) {
        return seenBatchIds[index];
    }

    function getMaxBatchStatusSeen(uint256 batchId) external view returns (Types.BatchStatus) {
        return maxBatchStatusSeen[batchId];
    }
}

contract BillStateMachineInvariantTest is StdInvariant, Test {
    KYARegistry internal registry;
    LockPoolManager internal pool;
    CircuitBreaker internal breaker;
    BillManager internal bill;
    AuthTokenManager internal auth;
    BillStateHandler internal handler;
    MockERC20 internal token;

    function setUp() public {
        registry = new KYARegistry();
        pool = new LockPoolManager(address(registry));
        breaker = new CircuitBreaker(address(this));
        auth = new AuthTokenManager();
        bill = new BillManager(address(pool), address(registry), address(breaker), address(auth));
        pool.setBillManager(address(bill));
        token = new MockERC20();

        handler = new BillStateHandler(registry, pool, bill, auth, token);
        targetContract(address(handler));
    }

    function invariant_BillStatusDoesNotRegress() public view {
        uint256 billCount = handler.getBillCount();
        for (uint256 i = 0; i < billCount; i++) {
            uint256 billId = handler.getBillIdAt(i);
            (, , , , , , , Types.BillStatus currentStatus, ,) = bill.bills(billId);
            Types.BillStatus maxSeen = handler.getMaxBillStatusSeen(billId);
            assertEq(uint8(currentStatus), uint8(maxSeen), "bill status tracking mismatch/regression");
        }
    }

    function invariant_BatchStatusDoesNotRegress() public view {
        uint256 batchCount = handler.getSeenBatchCount();
        for (uint256 i = 0; i < batchCount; i++) {
            uint256 batchId = handler.getSeenBatchIdAt(i);
            (,, , , Types.BatchStatus currentStatus,,) = bill.batches(batchId);
            Types.BatchStatus maxSeen = handler.getMaxBatchStatusSeen(batchId);
            assertEq(uint8(currentStatus), uint8(maxSeen), "batch status tracking mismatch/regression");
        }
    }

    function invariant_SettledOrCancelledBillsCannotBePendingOrConfirmed() public view {
        uint256 billCount = handler.getBillCount();
        for (uint256 i = 0; i < billCount; i++) {
            uint256 billId = handler.getBillIdAt(i);
            (, , , , , , , Types.BillStatus currentStatus, ,) = bill.bills(billId);
            Types.BillStatus maxSeen = handler.getMaxBillStatusSeen(billId);

            if (maxSeen == Types.BillStatus.Cancelled || maxSeen == Types.BillStatus.Settled) {
                assertTrue(
                    currentStatus == Types.BillStatus.Cancelled || currentStatus == Types.BillStatus.Settled,
                    "terminal bill state reverted"
                );
            }
        }
    }
}
