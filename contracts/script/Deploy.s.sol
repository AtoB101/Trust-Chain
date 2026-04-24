// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {KYARegistry} from "../core/KYARegistry.sol";
import {LockPoolManager} from "../core/LockPoolManager.sol";
import {AuthTokenManager} from "../core/AuthTokenManager.sol";
import {CircuitBreaker} from "../core/CircuitBreaker.sol";
import {BillManager} from "../core/BillManager.sol";

contract Deploy {
    struct DeployedContracts {
        address kyaRegistry;
        address lockPoolManager;
        address authTokenManager;
        address circuitBreaker;
        address billManager;
    }

    function run(address admin) external returns (DeployedContracts memory deployed) {
        KYARegistry kya = new KYARegistry();
        LockPoolManager lockPool = new LockPoolManager(address(kya));
        AuthTokenManager auth = new AuthTokenManager();
        CircuitBreaker breaker = new CircuitBreaker(admin);
        BillManager bill = new BillManager(address(lockPool), address(kya), address(breaker), address(auth));
        lockPool.setBillManager(address(bill));

        deployed = DeployedContracts({
            kyaRegistry: address(kya),
            lockPoolManager: address(lockPool),
            authTokenManager: address(auth),
            circuitBreaker: address(breaker),
            billManager: address(bill)
        });
    }
}
