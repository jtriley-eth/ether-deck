// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

library DeckTools {
    function encodeSetAuth(address account, bool authorized) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000001), account, authorized);
    }

    function encodeSetThreshold(uint8 threshold) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000002), threshold);
    }

    function encodeSetShard(bytes4 shard, address account) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000003), shard, account);
    }

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

    function hashSyscall(uint256 id, address target, uint88 value, uint64 deadline, bytes memory payload)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(id, target, value, deadline, uint32(payload.length), payload))
            )
        );
    }

    function idSlot() internal pure returns (bytes32) {
        return bytes32(0);
    }

    function thresholdSlot() internal pure returns (bytes32) {
        return bytes32(uint256(1));
    }

    function authSlot(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, 2));
    }

    function shardSlot(bytes4 selector) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint32(selector), 3));
    }
}
