// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import {DeckTools as dt} from "src/util/DeckTools.sol";
import "test/mock/MockTarget.sol";
import "lib/solmate/src/test/utils/mocks/MockERC20.sol";
import "lib/solmate/src/test/utils/mocks/MockERC721.sol";
import "lib/solmate/src/test/utils/mocks/MockERC1155.sol";
import "lib/solmate/src/tokens/ERC721.sol";
import "lib/solmate/src/tokens/ERC1155.sol";
import "lib/forge-std/src/Test.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract DeckCoinsTest is Test {
    uint256 constant SECP256K1_ORDER = 115792089237316195423570985008687907852837564279074904382605163141518161494337;
    uint256 constant PK_ALICE = 1;

    address alice = vm.addr(PK_ALICE);
    address deck;
    address shard;
    MockERC20 erc20;
    MockERC721 erc721;
    MockERC1155 erc1155;
    uint256 syscallId;

    modifier asActor(address actor) {
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    function setUp() public asActor(alice) {
        erc20 = new MockERC20("test token", "tt", 18);
        erc721 = new MockERC721("test token", "tt");
        erc1155 = new MockERC1155();
        deck = vm.compile("src/etherdeck.huff").create({value: 0});
        shard = vm.compile("src/shards/recv.huff").create({value: 0});  
        __enableRecv();
    }

    // ---------------------------------------------------------------------------------------------
    // Success Cases

    function testCanReceiveEther() public asActor(alice) {
        uint256 value = 1;
        vm.deal(alice, value);
        (bool success,) = deck.call{value: value}("");

        assertTrue(success);
        assertEq(alice.balance, 0);
        assertEq(deck.balance, value);
    }

    function testCanReceiveERC20() public asActor(alice) {
        uint256 value = 1;
        erc20.mint(alice, value);
        erc20.transfer(deck, value);

        assertEq(erc20.balanceOf(alice), 0);
        assertEq(erc20.balanceOf(deck), value);
    }

    function testCanReceiveERC721Safe() public asActor(alice) {
        uint256 id = 1;
        erc721.mint(alice, id);
        erc721.safeTransferFrom(alice, deck, id);

        assertEq(erc721.balanceOf(alice), 0);
        assertEq(erc721.balanceOf(deck), 1);
        assertEq(erc721.ownerOf(id), deck);
    }

    function testCanReceiveERC1155() public asActor(alice) {
        uint256 id = 1;
        uint256 value = 1;
        erc1155.mint(alice, id, value, "");
        erc1155.safeTransferFrom(alice, deck, id, value, "");

        assertEq(erc1155.balanceOf(alice, id), 0);
        assertEq(erc1155.balanceOf(deck, id), value);
    }

    function testCanReceiveERC1155Batch() public asActor(alice) {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        values[0] = 1;
        values[1] = 2;
        erc1155.batchMint(alice, ids, values, "");
        erc1155.safeBatchTransferFrom(alice, deck, ids, values, "");

        assertEq(erc1155.balanceOf(alice, ids[0]), 0);
        assertEq(erc1155.balanceOf(alice, ids[1]), 0);
        assertEq(erc1155.balanceOf(deck, ids[0]), values[0]);
        assertEq(erc1155.balanceOf(deck, ids[1]), values[1]);
    }

    function testCanSendEther() public {
        vm.deal(deck, 1);
        (bool success, ) = deck.call(__syscall(alice, 1, ""));

        assertTrue(success);
        assertEq(deck.balance, 0);
        assertEq(alice.balance, 1);
    }

    function testCanSendERC20() public {
        erc20.mint(deck, 1);
        (bool success, ) = deck.call(__syscall(address(erc20), 0, abi.encodeCall(ERC20.transfer, (alice, 1))));

        assertTrue(success);
        assertEq(erc20.balanceOf(deck), 0);
        assertEq(erc20.balanceOf(alice), 1);
    }

    function testCanSendERC721() public {
        uint256 id = 1;
        erc721.mint(deck, id);
        (bool success, ) = deck.call(__syscall(address(erc721), 0, abi.encodeCall(ERC721.transferFrom, (deck, alice, id))));

        assertTrue(success);
        assertEq(erc721.balanceOf(deck), 0);
        assertEq(erc721.balanceOf(alice), 1);
        assertEq(erc721.ownerOf(id), alice);
    }

    function testCanSendERC1155() public {
        uint256 id = 1;
        uint256 value = 1;
        erc1155.mint(deck, id, value, "");
        (bool success, ) = deck.call(__syscall(address(erc1155), 0, abi.encodeCall(ERC1155.safeTransferFrom, (deck, alice, id, value, ""))));

        assertTrue(success);
        assertEq(erc1155.balanceOf(deck, id), 0);
        assertEq(erc1155.balanceOf(alice, id), value);
    }

    function testCanSendERC1155Batch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        values[0] = 1;
        values[1] = 2;
        erc1155.batchMint(deck, ids, values, "");
        (bool success, ) = deck.call(__syscall(address(erc1155), 0, abi.encodeCall(ERC1155.safeBatchTransferFrom, (deck, alice, ids, values, ""))));

        assertTrue(success);
        assertEq(erc1155.balanceOf(deck, ids[0]), 0);
        assertEq(erc1155.balanceOf(deck, ids[1]), 0);
        assertEq(erc1155.balanceOf(alice, ids[0]), values[0]);
        assertEq(erc1155.balanceOf(alice, ids[1]), values[1]);
    }

    // ---------------------------------------------------------------------------------------------
    // Fuzz Tests

    function testFuzzCanReceiveEther(uint256 value, address sender, bytes memory payload) public asActor(sender) {
        vm.assume(sender != address(0));
        vm.assume(uint32(bytes4(payload)) > 4 || uint32(bytes4(payload)) == 0);
        vm.deal(sender, value);
        (bool success,) = deck.call{value: value}(payload);

        assertTrue(success);
        assertEq(sender.balance, 0);
        assertEq(deck.balance, value);
    }

    function testFuzzCanReceiveERC20(address sender, uint256 value) public asActor(sender) {
        vm.assume(sender != address(0));
        erc20.mint(sender, value);
        erc20.transfer(deck, value);

        assertEq(erc20.balanceOf(sender), 0);
        assertEq(erc20.balanceOf(deck), value);
    }

    function testFuzzCanReceiveERC721Safe(address sender, uint256 id) public asActor(sender) {
        vm.assume(sender != address(0));
        erc721.mint(sender, id);
        erc721.safeTransferFrom(sender, deck, id);

        assertEq(erc721.balanceOf(sender), 0);
        assertEq(erc721.balanceOf(deck), 1);
        assertEq(erc721.ownerOf(id), deck);
    }

    function testFuzzCanReceiveERC1155(address sender, uint256 id, uint256 value) public asActor(sender) {
        vm.assume(sender != address(0));
        vm.assume(sender.code.length == 0);
        erc1155.mint(sender, id, value, "");
        erc1155.safeTransferFrom(sender, deck, id, value, "");

        assertEq(erc1155.balanceOf(sender, id), 0);
        assertEq(erc1155.balanceOf(deck, id), value);
    }

    function testFuzzCanReceiveERC1155Batch(uint256[] memory ids, address sender) public asActor(sender) {
        vm.assume(sender.code.length == 0);
        uint256[] memory values = ids;
        address[] memory senders = new address[](ids.length);
        address[] memory receivers = new address[](ids.length);
        for (uint256 i; i < ids.length; ++i) (senders[i], receivers[i]) = (sender, deck);
        try erc1155.batchMint(sender, ids, values, "") {
            erc1155.safeBatchTransferFrom(sender, deck, ids, values, "");

            assertTrue(__gte(erc1155.balanceOfBatch(senders, ids), new uint256[](ids.length)));
            assertTrue(__gte(erc1155.balanceOfBatch(receivers, ids), values));
        } catch {
            // avoids mint arithmetic overflow. kinda hacky but it's on the 1155 side, not the deck.
        }
    }

    function testFuzzCanSendEther(address receiver, uint88 value) public {
        vm.assume(receiver.code.length == 0);
        uint256 receiverBalanceBefore = receiver.balance;
        vm.deal(deck, value);
        (bool success, ) = deck.call(__syscall(receiver, value, ""));

        assertTrue(success);
        assertEq(deck.balance, 0);
        assertEq(receiver.balance, receiverBalanceBefore + value);
    }

    function testFuzzCanSendERC20(address receiver, uint256 value) public {
        erc20.mint(deck, value);
        (bool success, ) = deck.call(__syscall(address(erc20), 0, abi.encodeCall(ERC20.transfer, (receiver, value))));

        assertTrue(success);
        assertEq(erc20.balanceOf(deck), 0);
        assertEq(erc20.balanceOf(receiver), value);
    }

    function testFuzzCanSendERC721(address receiver, uint256 id) public {
        vm.assume(receiver != address(0));
        erc721.mint(deck, id);
        (bool success, ) = deck.call(__syscall(address(erc721), 0, abi.encodeCall(ERC721.transferFrom, (deck, receiver, id))));

        assertTrue(success);
        assertEq(erc721.balanceOf(deck), 0);
        assertEq(erc721.balanceOf(receiver), 1);
        assertEq(erc721.ownerOf(id), receiver);
    }

    function testFuzzCanSendERC1155(address receiver, uint256 id, uint256 value) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver.code.length == 0);
        erc1155.mint(deck, id, value, "");
        (bool success, ) = deck.call(__syscall(address(erc1155), 0, abi.encodeCall(ERC1155.safeTransferFrom, (deck, receiver, id, value, ""))));

        assertTrue(success);
        assertEq(erc1155.balanceOf(deck, id), 0);
        assertEq(erc1155.balanceOf(receiver, id), value);
    }

    function testFuzzCanSendERC1155Batch(address receiver, uint256[] memory ids) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver.code.length == 0);
        uint256[] memory values = ids;
        address[] memory senders = new address[](ids.length);
        address[] memory receivers = new address[](ids.length);
        for (uint256 i; i < ids.length; ++i) (senders[i], receivers[i]) = (deck, receiver);
        try erc1155.batchMint(deck, ids, values, "") {
            (bool success, ) = deck.call(__syscall(address(erc1155), 0, abi.encodeCall(ERC1155.safeBatchTransferFrom, (deck, receiver, ids, values, ""))));

            assertTrue(success);
            assertTrue(__gte(erc1155.balanceOfBatch(senders, ids), new uint256[](ids.length)));
            assertTrue(__gte(erc1155.balanceOfBatch(receivers, ids), values));
        } catch {
            // avoids mint arithmetic overflow. kinda hacky but it's on the 1155 side, not the deck.
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Internals

    function __enableRecv() internal {
        // set shards for erc721 and erc1155

        bytes memory payload = dt.encodeSetShard(ERC721TokenReceiver.onERC721Received.selector, shard);

        (bool success, ) = deck.call(__syscall(deck, 0, payload));
        assertTrue(success);

        payload = dt.encodeSetShard(ERC1155TokenReceiver.onERC1155Received.selector, shard);
        (success,) = deck.call(__syscall(deck, 0, payload));
        assertTrue(success);

        payload = dt.encodeSetShard(ERC1155TokenReceiver.onERC1155BatchReceived.selector, shard);
        (success,) = deck.call(__syscall(deck, 0, payload));
        assertTrue(success);
    }

    function __syscall(address target, uint88 value, bytes memory payload) internal returns (bytes memory) {
        bytes[] memory signatures = new bytes[](1);
        uint256 currId = syscallId;
        syscallId += 1;
        signatures[0] = __sign(PK_ALICE, dt.hashSyscall({
            id: currId,
            target: target,
            value: value,
            deadline: type(uint64).max,
            payload: payload,
            chainId: block.chainid
        }));

        return dt.encodeSyscall({
            id: currId,
            target: target,
            value: value,
            deadline: type(uint64).max,
            payload: payload,
            signatures: signatures
        });
    }

    function __sign(uint256 pk, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(v, r, s);
    }

    function __gte(uint256[] memory lhs, uint256[] memory rhs) internal pure returns (bool) {
        if (lhs.length != rhs.length) return false;
        for (uint256 i; i < lhs.length; ++i) {
            if (lhs[i] < rhs[i]) {
                return false;
            }
        }
        return true;
    }
}
