// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import "lib/forge-std/src/Test.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract SpiderShardTest is Test {
    bytes4 constant SEL = bytes4(0x476d3d2e);
    address shard;

    function setUp() public {
        shard = vm.compile("src/shards/spider.huff").create({value: 0});
    }

    function testCrawlOne() public {
        bytes32 key = bytes32(uint256(1));
        bytes32 value = bytes32(uint256(2));

        vm.store(shard, key, value);

        (bool success, bytes memory data) = shard.call(abi.encodePacked(SEL, key));
        assertTrue(success);
        assertEq(value, bytes32(data));
    }

    function testCrawlTwo() public {
        bytes32[] memory keys = new bytes32[](2);
        bytes32[] memory values = new bytes32[](2);
        keys[0] = bytes32(uint256(1));
        keys[1] = bytes32(uint256(2));
        values[0] = bytes32(uint256(3));
        values[1] = bytes32(uint256(4));

        vm.store(shard, keys[0], values[0]);
        vm.store(shard, keys[1], values[1]);

        (bool success, bytes memory data) = shard.call(abi.encodePacked(SEL, keys));
        assertTrue(success);
        assertTrue(__check(values, data));
    }

    function testFuzzCrawl(bytes32[] memory keys) public {
        bytes32[] memory values = keys;

        for (uint256 i = 0; i < keys.length; i++) {
            vm.store(shard, keys[i], values[i]);
        }

        (bool success, bytes memory data) = shard.call(abi.encodePacked(SEL, keys));
        assertTrue(success);
        assertTrue(__check(values, data));
    }

    function __check(bytes32[] memory values, bytes memory data) internal returns (bool) {
        if (values.length == 0) {
            return bytes32(data) == bytes32(0);
        }

        if (values.length != data.length / 32) {
            return false;
        }

        for (uint256 i = 0; i < values.length; i++) {
            bytes32 value;
            assembly {
                value := mload(add(data, add(32, mul(i, 32))))
            }
            if (value != values[i]) {
                return false;
            }
        }

        return true;
    }
}
