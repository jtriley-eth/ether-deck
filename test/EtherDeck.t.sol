// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import {DeckTools as dt} from "src/util/DeckTools.sol";
import "test/mock/MockTarget.sol";
import "lib/forge-std/src/Test.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract EtherDeckTest is Test {
    uint256 constant PK_ALICE = 1;
    uint256 constant PK_BOB = 2;
    uint256 constant PK_CHARLIE = 3;
    uint256 constant PK_DAN = 4;
    uint256 constant PK_EVE = 5;

    address immutable alice = vm.addr(PK_ALICE);
    address immutable bob = vm.addr(PK_BOB);
    address immutable charlie = vm.addr(PK_CHARLIE);
    address immutable dan = vm.addr(PK_DAN);
    address immutable eve = vm.addr(PK_EVE);

    address deck;
    address mockTarget;

    modifier asActor(address actor) {
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    function setUp() public asActor(alice) {
        deck = vm.compile("src/etherdeck.huff").create({value: 0});
        mockTarget = address(new MockTarget());
    }

    function testInitialStorage() public {
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 1);
        assertEq(uint256(vm.load(deck, dt.authSlot(alice))), 1);
    }

    function testSetAuth() public {
        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetAuth(bob, true)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.authSlot(bob))), 1);
    }

    function testFuzzSetAuth(address actor) public {
        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetAuth(actor, true)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.authSlot(actor))), 1);
    }

    function testSetThreshold() public {
        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetThreshold(2)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 2);
    }

    function testFuzzSetThreshold(uint8 threshold) public {
        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetThreshold(threshold)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), threshold);
    }

    function testSetShard() public {
        bytes4 selector = 0xaabbccdd;
        address shard = mockTarget;
        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetShard(selector, shard)));

        assertTrue(success);
        assertEq(address(uint160(uint256(vm.load(deck, dt.shardSlot(selector))))), shard);
    }

    function testFuzzSetShard(bytes4 selector, address shard) public {
        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetShard(selector, shard)));

        assertTrue(success);
        assertEq(address(uint160(uint256(vm.load(deck, dt.shardSlot(selector))))), shard);
    }

    function __defaultSyscall(bytes memory payload) internal view returns (bytes memory) {
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(PK_ALICE, dt.hashSyscall({
            id: 0,
            target: deck,
            value: 0,
            deadline: type(uint64).max,
            payload: payload
        }));
        return dt.encodeSyscall({
            id: 0,
            target: deck,
            value: 0,
            deadline: type(uint64).max,
            payload: payload,
            signatures: signatures
        });
    }

    function __sign(uint256 pk, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(v, r, s);
    }
}
