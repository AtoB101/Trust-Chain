// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBillManager} from "../interfaces/IBillManager.sol";
import {Errors} from "../libraries/Errors.sol";

contract BatchSettlement {
    address public immutable admin;
    IBillManager public immutable billManager;

    constructor(address admin_, address billManager_) {
        if (admin_ == address(0) || billManager_ == address(0)) revert Errors.InvalidAddress();
        admin = admin_;
        billManager = IBillManager(billManager_);
    }

    /// @dev Deprecated compatibility entry point.
    /// Settlement actions must be invoked directly on BillManager by pool owner.
    function closeBatch(uint256 batchId) external {
        batchId;
        revert Errors.DeprecatedEntryPoint();
    }

    /// @dev Deprecated compatibility entry point.
    /// Settlement actions must be invoked directly on BillManager by pool owner.
    function settleBatch(uint256 batchId) external {
        batchId;
        revert Errors.DeprecatedEntryPoint();
    }
}
