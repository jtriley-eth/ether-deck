// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import "lib/forge-std/src/Test.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

interface IPubStoreShard {
    function loadStorage(bytes32 slot) external view returns (bytes32);
}

contract RecvShardTest is Test {
    address shard;

    function setUp() public {
        shard = vm.compile("src/shards/pubstore.huff").create({value: 0});
    }

    function testLoadStorage() public {
        bytes32 slot = bytes32(uint256(1));
        bytes32 value = bytes32(uint256(2));

        vm.store(shard, slot, value);

        assertEq(IPubStoreShard(shard).loadStorage(slot), value);
    }

    function testFuzzLoadStorage(bytes32 slot, bytes32 value) public {
        vm.store(shard, slot, value);

        assertEq(IPubStoreShard(shard).loadStorage(slot), value);
    }
}
