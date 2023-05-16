// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import {DeckTools as dt} from "src/util/DeckTools.sol";
import "test/mock/MockTarget.sol";
import "lib/forge-std/src/Test.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract EtherDeckTest is Test {
    uint256 constant SECP256K1_ORDER =
        115792089237316195423570985008687907852837564279074904382605163141518161494337;

    uint256 constant PK_ALICE = 1;
    uint256 constant PK_BOB = 2;
    uint256 constant PK_CHARLIE = 3;

    address immutable alice = vm.addr(PK_ALICE);
    address immutable bob = vm.addr(PK_BOB);
    address immutable charlie = vm.addr(PK_CHARLIE);

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

    // ---------------------------------------------------------------------------------------------
    // Success Cases

    function testInitialStorage() public {
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 1);
        assertEq(uint256(vm.load(deck, dt.authSlot(alice))), 1);
    }

    function testSetAuth() public {
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(bob, true);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetAuth(bob, true))
        );

        assertTrue(success);
        assertEq(__toBool(vm.load(deck, dt.authSlot(bob))), true);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testUnsetAuth() public {
        vm.expectCall(deck, 0, dt.encodeSetAuth(bob, true), 1);
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(bob, true);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetAuth(bob, true))
        );

        assertTrue(success);
        assertEq(__toBool(vm.load(deck, dt.authSlot(bob))), true);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);

        vm.expectCall(deck, 0, dt.encodeSetAuth(bob, false), 1);
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(bob, false);

        (success, ) = deck.call(
            __selfSyscall(1, PK_ALICE, dt.encodeSetAuth(bob, false))
        );

        assertTrue(success);
        assertEq(__toBool(vm.load(deck, dt.authSlot(bob))), false);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 2);
    }

    function testSetThreshold() public {
        vm.expectCall(deck, 0, dt.encodeSetThreshold(2), 1);
        vm.expectEmit(true, true, true, true, deck);
        emit ThresholdSet(2);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetThreshold(2))
        );

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 2);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testSetShard() public {
        bytes4 selector = 0xaabbccdd;
        address shard = mockTarget;

        vm.expectCall(deck, 0, dt.encodeSetShard(selector, shard), 1);
        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, shard);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetShard(selector, shard))
        );

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), shard);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testUnsetShard() public {
        bytes4 selector = 0xaabbccdd;
        address shard = mockTarget;

        vm.expectCall(deck, 0, dt.encodeSetShard(selector, shard), 1);
        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, shard);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetShard(selector, shard))
        );

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), shard);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);

        vm.expectCall(deck, 0, dt.encodeSetShard(selector, address(0)), 1);
        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, address(0));

        (success, ) = deck.call(
            __selfSyscall(1, PK_ALICE, dt.encodeSetShard(selector, address(0)))
        );

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), address(0));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 2);
    }

    function testSyscall() public {
        bytes memory payload = abi.encodeCall(MockTarget.succeeds, (42));
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: mockTarget,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
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

    function testTwoSignatures() public {
        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetAuth(bob, true))
        );
        assertTrue(success);
        assertTrue(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);

        (success, ) = deck.call(
            __selfSyscall(1, PK_ALICE, dt.encodeSetThreshold(2))
        );
        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 2);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 2);

        bytes memory payload = dt.encodeSetAuth(charlie, true);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 2,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );
        signatures[1] = __sign(
            PK_BOB,
            dt.hashSyscall({
                id: 2,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );

        if (uint160(alice) > uint160(bob)) {
            (signatures[0], signatures[1]) = (signatures[1], signatures[0]);
        }

        vm.expectCall(deck, 0, payload, 1);
        vm.expectEmit(true, true, true, true, deck);
        emit Syscall(2);

        (success, ) = deck.call(
            dt.encodeSyscall({
                id: 2,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            })
        );
        assertTrue(success);
        assertTrue(__toBool(vm.load(deck, dt.authSlot(charlie))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 3);
    }

    function testIgnoreExtraSignatures() public {
        bytes memory payload = dt.encodeSetAuth(bob, true);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );
        signatures[1] = __sign(
            PK_CHARLIE,
            dt.hashSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );

        vm.expectCall(deck, 0, payload, 1);
        vm.expectEmit(true, true, true, true, deck);
        emit Syscall(0);

        (bool success, ) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            })
        );

        assertTrue(success);
        assertTrue(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testUseShard() public {
        (bool success, ) = deck.call(
            __selfSyscall(
                0,
                PK_ALICE,
                dt.encodeSetShard(MockTarget.succeeds.selector, mockTarget)
            )
        );

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(MockTarget.succeeds.selector))), mockTarget);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);

        uint256 res = MockTarget(payable(deck)).succeeds(42);
        assertEq(res, 42);
    }

    // ---------------------------------------------------------------------------------------------
    // Failure Cases

    function testUnauthorizedSigner() public {
        (bool success, bytes memory retdata) = deck.call(
            __selfSyscall(0, PK_BOB, dt.encodeSetAuth(bob, true))
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(bytes4(retdata), dt.Auth.selector);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
    }

    function testInvalidSignature() public {
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"beef";

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: dt.encodeSetAuth(bob, true),
                signatures: signatures
            })
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testNoHardForkReplay() public {
        bytes memory payload = dt.encodeSetAuth(bob, true);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );

        vm.chainId(block.chainid + 1);

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            })
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testDeadline() public {
        bytes memory payload = dt.encodeSetAuth(bob, true);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: uint64(block.timestamp),
                payload: payload,
                chainId: block.chainid
            })
        );

        vm.warp(block.timestamp + 1);

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: uint64(block.timestamp),
                payload: payload,
                signatures: signatures
            })
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
        assertEq(bytes4(retdata), dt.Deadline.selector);
    }

    function testSetAuthExternal() public asActor(alice) {
        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSetAuth(bob, true)
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testSetThresholdExternal() public asActor(alice) {
        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSetThreshold(2)
        );

        assertFalse(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 1);
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testSetShardExternal() public asActor(alice) {
        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSetShard(0xaabbccdd, address(1))
        );

        assertFalse(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(0xaabbccdd))), address(0));
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testUseShardRevert() public {
        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetShard(MockTarget.fails.selector, mockTarget))
        );

        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(MockTarget.fails.selector))), mockTarget);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);

        vm.expectRevert(MockTarget.Fail.selector);
        MockTarget(payable(deck)).fails();
    }

    // ---------------------------------------------------------------------------------------------
    // Fuzz Tests

    function testFuzzSetAuth(address account, bool auth) public {
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(account, auth);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetAuth(account, auth))
        );

        assertTrue(success);
        assertTrue(__toBool(vm.load(deck, dt.authSlot(account))) == auth);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    /// forge-config: default.fuzz.runs = 256
    function testFuzzSetThreshold(uint8 threshold) public {
        vm.expectEmit(true, true, true, true, deck);
        emit ThresholdSet(threshold);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetThreshold(threshold))
        );

        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), threshold);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testFuzzSetShard(bytes4 selector, address shard) public {
        vm.expectEmit(true, true, true, true, deck);
        emit ShardSet(selector, shard);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetShard(selector, shard))
        );

        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
        assertTrue(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), shard);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testFuzzSyscall(
        address target,
        uint88 value,
        bytes4 selector
    ) public asActor(alice) {
        vm.deal(alice, value);
        vm.assume(uint160(target) > 255 && target != address(vm));

        bytes memory payload = abi.encodePacked(selector);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: target,
                value: value,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );

        (bool success, bytes memory retdata) = target.call{value: value}(
            payload
        );

        vm.deal(alice, value);

        vm.expectEmit(true, true, true, true, deck);
        emit Syscall(0);

        (bool deckSuccess, bytes memory deckRetdata) = deck.call{value: value}(
            dt.encodeSyscall({
                id: 0,
                target: target,
                value: value,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            })
        );

        assertTrue(success == deckSuccess);
        assertEq(keccak256(retdata), keccak256(deckRetdata));
        assertEq(uint256(vm.load(deck, dt.idSlot())), deckSuccess ? 1 : 0);
    }

    function testFuzzChainId(uint64 chainId) public {
        vm.chainId(chainId);

        vm.expectCall(deck, 0, dt.encodeSetAuth(bob, true), 1);
        vm.expectEmit(true, true, true, true, deck);
        emit AuthSet(bob, true);

        (bool success, ) = deck.call(
            __selfSyscall(0, PK_ALICE, dt.encodeSetAuth(bob, true))
        );
        assertTrue(success);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
    }

    function testFuzzUnauthorizedSigner(uint256 pk) public {
        // constrain pk to be in the secp256k1 curve order.
        pk %= SECP256K1_ORDER;
        pk += pk == 0 ? 1 : 0;
        vm.assume(pk != PK_ALICE);
        address attacker = vm.addr(pk);

        (bool success, bytes memory retdata) = deck.call(
            __selfSyscall(0, pk, dt.encodeSetAuth(attacker, true))
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(attacker))));
        assertEq(bytes4(retdata), dt.Auth.selector);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
    }

    function testFuzzInvalidSignature(bytes memory signature) public {
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: dt.encodeSetAuth(bob, true),
                signatures: signatures
            })
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(bytes4(retdata), dt.Auth.selector);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
    }

    function testFuzzNoHardForkReplay(uint64 chainId) public {
        vm.assume(chainId != block.chainid);

        bytes memory payload = dt.encodeSetAuth(bob, true);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );

        vm.chainId(chainId);

        (bool success, ) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                signatures: signatures
            })
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
    }

    function testFuzzDeadline(uint64 deadline, uint64 minedAt) public {
        bytes memory payload = dt.encodeSetAuth(bob, true);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            PK_ALICE,
            dt.hashSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: deadline,
                payload: payload,
                chainId: block.chainid
            })
        );

        vm.warp(minedAt);

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSyscall({
                id: 0,
                target: deck,
                value: 0,
                deadline: deadline,
                payload: payload,
                signatures: signatures
            })
        );

        if (minedAt < deadline) {
            assertTrue(success);
            assertTrue(__toBool(vm.load(deck, dt.authSlot(bob))));
            assertEq(uint256(vm.load(deck, dt.idSlot())), 1);
        } else {
            assertFalse(success);
            assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
            assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
            assertEq(bytes4(retdata), dt.Deadline.selector);
        }
    }

    function testFuzzSetAuthExternal(address actor) public asActor(actor) {
        vm.assume(actor != deck);

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSetAuth(bob, true)
        );

        assertFalse(success);
        assertFalse(__toBool(vm.load(deck, dt.authSlot(bob))));
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testFuzzSetThresholdExternal(address actor) public asActor(actor) {
        vm.assume(actor != deck);

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSetThreshold(2)
        );

        assertFalse(success);
        assertEq(uint256(vm.load(deck, dt.thresholdSlot())), 1);
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testFuzzSetShardExternal(
        address actor,
        bytes4 selector,
        address shard
    ) public asActor(actor) {
        vm.assume(actor != deck);

        (bool success, bytes memory retdata) = deck.call(
            dt.encodeSetShard(selector, shard)
        );

        assertFalse(success);
        assertEq(__toAddr(vm.load(deck, dt.shardSlot(selector))), address(0));
        assertEq(bytes4(retdata), dt.Auth.selector);
    }

    function testFuzzCalldata(
        address actor,
        bytes memory payload
    ) public asActor(actor) {
        vm.assume(actor != deck);

        (bool success, ) = deck.call(payload);

        assertFalse(success);
        assertEq(uint256(vm.load(deck, dt.idSlot())), 0);
    }

    // ---------------------------------------------------------------------------------------------
    // Internals

    function __selfSyscall(
        uint256 id,
        uint256 pk,
        bytes memory payload
    ) internal view returns (bytes memory) {
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = __sign(
            pk,
            dt.hashSyscall({
                id: id,
                target: deck,
                value: 0,
                deadline: type(uint64).max,
                payload: payload,
                chainId: block.chainid
            })
        );
        return
            dt.encodeSyscall({
                id: id,
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
