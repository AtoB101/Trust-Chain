// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {KYARegistry} from "../core/KYARegistry.sol";
import {LockPoolManager} from "../core/LockPoolManager.sol";
import {Errors} from "../libraries/Errors.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract LockPoolManagerTest is Test {
    KYARegistry internal registry;
    LockPoolManager internal manager;
    MockERC20 internal token;
    address internal owner = address(0xABCD);
    address internal agent = address(0xA11CE);

    function setUp() public {
        registry = new KYARegistry();
        manager = new LockPoolManager(address(registry));
        token = new MockERC20();
        vm.deal(owner, 1 ether);
        token.mint(owner, 1_000_000);
        vm.prank(owner);
        token.approve(address(manager), type(uint256).max);
    }

    function testCreatePoolAfterDIDRegistration() public {
        vm.startPrank(owner);
        registry.registerDID{value: 0.01 ether}(agent, keccak256("pool-perm"), 30);
        bytes32 poolId = manager.createLockPool(agent, address(token), 1000);
        vm.stopPrank();

        uint256 mappingBalance = manager.getMappingBalance(poolId);
        assertEq(mappingBalance, 1000, "mapping balance should match");
    }

    function testTopUpAndWithdrawMaintainsMappingBalance() public {
        vm.startPrank(owner);
        registry.registerDID{value: 0.01 ether}(agent, keccak256("pool-perm"), 30);
        bytes32 poolId = manager.createLockPool(agent, address(token), 1000);
        manager.topUpLockPool(poolId, 250);
        manager.withdrawLockPool(poolId, 100);
        vm.stopPrank();

        uint256 mappingBalance = manager.getMappingBalance(poolId);
        assertEq(mappingBalance, 1150, "mapping should be create+topup-withdraw");
    }

    function testWithdrawRevertsForInsufficientBalance() public {
        vm.startPrank(owner);
        registry.registerDID{value: 0.01 ether}(agent, keccak256("pool-perm"), 30);
        bytes32 poolId = manager.createLockPool(agent, address(token), 1000);
        vm.expectRevert(Errors.InsufficientMappingBalance.selector);
        manager.withdrawLockPool(poolId, 2000);
        vm.stopPrank();
    }
}
