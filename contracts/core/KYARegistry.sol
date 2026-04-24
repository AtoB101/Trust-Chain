// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IKYARegistry} from "../interfaces/IKYARegistry.sol";
import {Types} from "../libraries/Types.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";

contract KYARegistry is IKYARegistry {
    mapping(address agent => Types.AgentDID) public didByAgent;
    uint256 public constant MIN_STAKE = 0.01 ether;

    function registerDID(address agent, bytes32 permissionsHash, uint256 validityDays)
        external
        payable
        override
        returns (bytes32 did)
    {
        if (agent == address(0)) revert Errors.InvalidAddress();
        if (msg.value < MIN_STAKE) revert Errors.InvalidAmount();
        if (validityDays == 0) revert Errors.InvalidAmount();

        uint256 validUntil = block.timestamp + (validityDays * 1 days);
        did = keccak256(abi.encodePacked(msg.sender, agent, block.timestamp, permissionsHash));

        didByAgent[agent] = Types.AgentDID({
            owner: msg.sender,
            agent: agent,
            registeredAt: block.timestamp,
            validUntil: validUntil,
            permissionsHash: permissionsHash,
            isActive: true
        });

        emit Events.DIDRegistered(did, agent, msg.sender, validUntil);
    }

    function revokeDID(address agent) external override {
        Types.AgentDID storage did = didByAgent[agent];
        if (did.owner != msg.sender) revert Errors.Unauthorized();
        if (!did.isActive) revert Errors.InvalidState();

        did.isActive = false;
        emit Events.DIDRevoked(agent, msg.sender);
    }

    function verifyDID(address agent) external view override returns (bool isValid, address owner, uint256 validUntil) {
        Types.AgentDID memory did = didByAgent[agent];
        isValid = did.isActive && did.validUntil >= block.timestamp;
        owner = did.owner;
        validUntil = did.validUntil;
    }

    function updatePermissions(address agent, bytes32 newPermissionsHash) external override {
        Types.AgentDID storage did = didByAgent[agent];
        if (did.owner != msg.sender) revert Errors.Unauthorized();
        if (!did.isActive) revert Errors.DIDNotActive();

        did.permissionsHash = newPermissionsHash;
        emit Events.PermissionUpdated(agent, newPermissionsHash);
    }
}
