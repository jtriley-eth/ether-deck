// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

library MulticallShardTools {
    struct Call {
        address target;
        uint88 value;
        bytes payload;
    }

    bytes4 constant SIG = 0x1cdcf85a;

    function encodeCalls(
        bool mayFail,
        Call[] memory calls
    ) internal pure returns (bytes memory data) {
        uint32 totalLen;
        for (uint256 i = 0; i < calls.length; i++) {
            totalLen += 20 + 11 + 4 + uint32(calls[i].payload.length);
            data = abi.encodePacked(
                data,
                calls[i].target,
                calls[i].value,
                uint32(calls[i].payload.length),
                calls[i].payload
            );
        }
        data = abi.encodePacked(SIG, mayFail, totalLen, data);
    }
}
