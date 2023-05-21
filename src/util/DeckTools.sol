// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

/// @title Ether Deck Tooling
/// @notice Pure utility functions for interfacing with the deck
library DeckTools {
    error Auth();
    error Deadline();

    /// @notice Encodes a setAuth call
    /// @param account The account to set authorization for
    /// @param authorized Whether the account should be authorized
    function encodeSetAuth(address account, bool authorized) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000001), account, authorized);
    }

    /// @notice Encodes a setThreshold call
    /// @param threshold The new threshold
    function encodeSetThreshold(uint8 threshold) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000002), threshold);
    }

    /// @notice Encodes a setShard call
    /// @param selector The selector to dispatch the shard with
    /// @param shard The shard to call
    function encodeSetShard(bytes4 selector, address shard) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000003), selector, shard);
    }

    /// @notice Encodes a syscall
    /// @param id The syscall id
    /// @param target The target address
    /// @param value The value to send
    /// @param deadline The deadline for the call
    /// @param payload The payload for the call
    /// @param signatures The signatures for the call
    function encodeSyscall(
        uint256 id,
        address target,
        uint88 value,
        uint64 deadline,
        bytes memory payload,
        bytes[] memory signatures
    ) internal pure returns (bytes memory) {
        bytes memory packedSigs;
        for (uint256 i; i < signatures.length; i++) {
            packedSigs = abi.encodePacked(packedSigs, signatures[i]);
        }
        return abi.encodePacked(
            bytes4(0x00000004), id, target, value, deadline, uint32(payload.length), payload, packedSigs
        );
    }

    /// @notice Hashes a syscall for signing
    /// @param id The syscall id
    /// @param target The target address
    /// @param value The value to send
    /// @param deadline The deadline for the call
    /// @param payload The payload for the call
    function hashSyscall(
        uint256 id,
        address target,
        uint88 value,
        uint64 deadline,
        bytes memory payload,
        uint256 chainId
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(id, target, value, deadline, uint32(payload.length), payload, chainId))
            )
        );
    }

    /// @notice ID slot on the deck
    function idSlot() internal pure returns (bytes32) {
        return bytes32(0);
    }

    /// @notice Threshold slot on the deck
    function thresholdSlot() internal pure returns (bytes32) {
        return bytes32(uint256(1));
    }

    /// @notice Authorization slot for an account on the deck
    function authSlot(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, 2));
    }

    /// @notice Shard slot for an account on the deck
    function shardSlot(bytes4 selector) internal pure returns (bytes32) {
        return keccak256(abi.encode(bytes32(selector), 3));
    }
}
