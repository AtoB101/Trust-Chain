// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {KYARegistry} from "../core/KYARegistry.sol";
import {LockPoolManager} from "../core/LockPoolManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract LockPoolHandler is Test {
    KYARegistry internal registry;
    LockPoolManager internal manager;
    MockERC20 internal token;

    address[] internal owners;
    address[] internal agents;
    bytes32[] internal poolIds;
    mapping(address => bytes32[]) internal poolsByOwner;

    constructor(KYARegistry _registry, LockPoolManager _manager, MockERC20 _token) {
        registry = _registry;
        manager = _manager;
        token = _token;

        owners.push(address(0xA1));
        owners.push(address(0xA2));
        owners.push(address(0xA3));

        agents.push(address(0xB1));
        agents.push(address(0xB2));
        agents.push(address(0xB3));

        for (uint256 i = 0; i < owners.length; i++) {
            vm.deal(owners[i], 10 ether);
            vm.prank(owners[i]);
            registry.registerDID{value: 0.01 ether}(agents[i], keccak256(abi.encodePacked("perm-", i)), 365);
            token.mint(owners[i], 10_000_000);
            vm.prank(owners[i]);
            token.approve(address(manager), type(uint256).max);
        }
    }

    function createPool(uint256 ownerSeed, uint256 amountSeed) external {
        address owner = owners[ownerSeed % owners.length];
        uint256 idx = ownerSeed % agents.length;
        address agent = agents[idx];

        uint256 amount = bound(amountSeed, 1, 10_000);
        vm.prank(owner);
        bytes32 poolId = manager.createLockPool(agent, address(token), amount);
        poolIds.push(poolId);
        poolsByOwner[owner].push(poolId);
    }

    function topUp(uint256 ownerSeed, uint256 poolSeed, uint256 amountSeed) external {
        address owner = owners[ownerSeed % owners.length];
        bytes32[] memory ownedPools = poolsByOwner[owner];
        if (ownedPools.length == 0) return;

        bytes32 poolId = ownedPools[poolSeed % ownedPools.length];
        uint256 amount = bound(amountSeed, 1, 5_000);
        vm.prank(owner);
        manager.topUpLockPool(poolId, amount);
    }

    function withdraw(uint256 ownerSeed, uint256 poolSeed, uint256 amountSeed) external {
        address owner = owners[ownerSeed % owners.length];
        bytes32[] memory ownedPools = poolsByOwner[owner];
        if (ownedPools.length == 0) return;

        bytes32 poolId = ownedPools[poolSeed % ownedPools.length];
        (,,, , uint256 totalLocked, uint256 mappingBalance,, , ,) = manager.pools(poolId);
        if (totalLocked == 0 || mappingBalance == 0) return;

        uint256 amount = bound(amountSeed, 1, mappingBalance);
        vm.prank(owner);
        manager.withdrawLockPool(poolId, amount);
    }

    function getPoolCount() external view returns (uint256) {
        return poolIds.length;
    }

    function getPoolIdAt(uint256 index) external view returns (bytes32) {
        return poolIds[index];
    }
}

contract LockPoolManagerInvariantTest is StdInvariant, Test {
    KYARegistry internal registry;
    LockPoolManager internal manager;
    LockPoolHandler internal handler;
    MockERC20 internal token;

    function setUp() public {
        registry = new KYARegistry();
        manager = new LockPoolManager(address(registry));
        token = new MockERC20();
        handler = new LockPoolHandler(registry, manager, token);
        targetContract(address(handler));
    }

    function invariant_MappingBalanceNeverExceedsTotalLocked() public view {
        uint256 count = handler.getPoolCount();
        for (uint256 i = 0; i < count; i++) {
            bytes32 poolId = handler.getPoolIdAt(i);
            (,,, , uint256 totalLocked, uint256 mappingBalance,, , ,) = manager.pools(poolId);
            assertLe(mappingBalance, totalLocked, "mappingBalance exceeds totalLocked");
        }
    }

    function invariant_TotalLockedAndMappingBalanceNonNegative() public view {
        uint256 count = handler.getPoolCount();
        for (uint256 i = 0; i < count; i++) {
            bytes32 poolId = handler.getPoolIdAt(i);
            (,,, , uint256 totalLocked, uint256 mappingBalance,, , ,) = manager.pools(poolId);
            assertGe(totalLocked, 0, "totalLocked negative");
            assertGe(mappingBalance, 0, "mappingBalance negative");
        }
    }
}
