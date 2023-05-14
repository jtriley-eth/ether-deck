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

        (bool success, ) = deck.call(
            __selfSyscall(dt.encodeSetAuth(bob, true))
        );

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.authSlot(bob))), 1);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testFuzzSetAuth(address account, bool auth) public {
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(account, auth);

        (bool success, ) = deck.call(
            __selfSyscall(dt.encodeSetAuth(account, auth))
        );

        assertTrue(success);
        assertTrue(__toBool(vm.load(deck, dt.authSlot(account))) == auth);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testSetThreshold() public {
        vm.expectEmit(true, true, true, true, deck);
        emit ThresholdSet(2);

        (bool success, ) = deck.call(__selfSyscall(dt.encodeSetThreshold(2)));

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 2);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    /// forge-config: default.fuzz.runs = 256
    function testFuzzSetThreshold(uint8 threshold) public {
        vm.expectEmit(true, true, true, true, deck);
        emit ThresholdSet(threshold);

        (bool success, ) = deck.call(
            __selfSyscall(dt.encodeSetThreshold(threshold))
        );

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), threshold);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testSetShard() public {
        bytes4 selector = 0xaabbccdd;
        address shard = mockTarget;

        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, shard);

        (bool success, ) = deck.call(
            __selfSyscall(dt.encodeSetShard(selector, shard))
        );

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), shard);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testFuzzSetShard(bytes4 selector, address shard) public {
        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, shard);

        (bool success, ) = deck.call(
            __selfSyscall(dt.encodeSetShard(selector, shard))
        );

        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), shard);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testSyscall() public {
        bytes memory payload = abi.encodeCall(
            MockTarget.succeeds,
            (42)
        );
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: mockTarget,
                value: 0,
                deadline: type(uint64).max,
                payload: payload
            })
        );

        vm.expectCall(mockTarget, 0, payload, 1);
        vm.expectEmit(true, true, true, true, deck);
        emit Syscall(0);

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: mockTarget,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            })
        );

        assertTrue(success);
        assertEq(keccak256(retdata), keccak256(abi.encodePacked(uint256(42))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testFuzzSyscall(address target, uint88 value, bytes4 selector) public {
        // assume target is not a precompile and no the mock target
        vm.assume(uint160(target) > uint160(256) && target != mockTarget);

        bytes memory payload = abi.encodePacked(selector);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: target,
                value: value,
                deadline: type(uint64).max,
                payload: payload
            })
        );

        vm.expectCall(target, value, payload, 1);
        vm.expectEmit(true, true, true, true, deck);
        emit Syscall(0);

        (bool success,) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: target,
                value: value,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            })
        );

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    // ---------------------------------------------------------------------------------------------
    // Internals

    function __selfSyscall(
        bytes memory payload
    ) internal view returns (bytes memory) {
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload
            })
        );
        return
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            });
    }

    function __sign(
        uint256 pk,
        bytes32 hash
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(v, r, s);
    }

    function __toBool(bytes32 value) internal pure returns (bool b) {
        // how hard could this possibly mf be bruv
        assembly {
            b := iszero(iszero(value))
        }
    }

    function __toAddr(bytes32 value) internal pure returns (address a) {
        assembly {
            a := shr(96, shl(96, value))
        }
    }
}
