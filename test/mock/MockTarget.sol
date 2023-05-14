// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

contract MockTarget {
    error Fail();

    function succeeds(uint256 a) public pure returns (uint256) {
        return a;
    }

    function fails() public pure {
        revert Fail();
    }
}
