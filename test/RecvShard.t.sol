// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import "test/mock/MockERC1155.sol";
import "test/mock/MockERC721.sol";
import "lib/forge-std/src/Test.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract RecvShardTest is Test {
    address shard;
    MockERC1155 erc1155;
    MockERC721 erc721;

    function setUp() public {
        shard = vm.compile("src/shards/recv.huff").create({value: 0});
        erc1155 = new MockERC1155();
        erc721 = new MockERC721();
    }

    function testERC1155() public {
        erc1155.callOnERC1155Received(shard, address(1), address(1), 1, 1, bytes("1"));
    }

    function testERC721() public {
        erc721.callOnERC721Received(shard, address(1), address(1), 1, bytes("1"));
    }

    function testFuzzReturnSelector(bytes4 selector) public {
        (bool success, bytes memory retdata) = shard.call(abi.encodePacked(selector));

        assertTrue(success);
        assertEq(bytes4(retdata), selector);
    }
}
