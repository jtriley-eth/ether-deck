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

    event AuthSet(address indexed account, bool indexed auth);
    event ThresholdSet(uint8 indexed threshold);
    event ShardSet(bytes4 indexed selector, address indexed shard);
    event Syscall(uint256 indexed id);

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
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(bob, true);

        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetAuth(bob, true)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.authSlot(bob))), 1);
    }

    function testFuzzSetAuth(address account, bool auth) public {
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(account, auth);

        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetAuth(account, auth)));

        assertTrue(success);
        assertTrue(__toBool(vm.load(deck, dt.authSlot(account))) == auth);
    }

    function testSetThreshold() public {
        vm.expectEmit(true, true, true, true, deck);
        emit ThresholdSet(2);

        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetThreshold(2)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 2);
    }

    /// forge-config: default.fuzz.runs = 256
    function testFuzzSetThreshold(uint8 threshold) public {
        vm.expectEmit(true, true, true, true, deck);
        emit ThresholdSet(threshold);

        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetThreshold(threshold)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), threshold);
    }

    function testSetShard() public {
        bytes4 selector = 0xaabbccdd;
        address shard = mockTarget;

        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, shard);

        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetShard(selector, shard)));

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), shard);
    }

    function testFuzzSetShard(bytes4 selector, address shard) public {
        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, shard);

        (bool success,) = deck.call(__defaultSyscall(dt.encodeSetShard(selector, shard)));

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), shard);
    }

    // ---------------------------------------------------------------------------------------------
    // Internals

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

    function __toBool(bytes32 value) internal pure returns (bool b) {
        // how hard could this possibly mf be bruv
        assembly { b := iszero(iszero(value)) }
    }

    function __toAddr(bytes32 value) internal pure returns (address a) {
        assembly { a := shr(96, shl(96, value)) }
    }
}
