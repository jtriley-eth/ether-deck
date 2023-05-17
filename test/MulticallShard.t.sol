// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import {MulticallShardTools as mst} from "src/util/MulticallShardTools.sol";
import "test/mock/MockTarget.sol";
import "lib/forge-std/src/Test.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract MulticallShardTest is Test {
    address shard;
    address mockTarget;

    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // since the multicaller requires that `msg.sender == address(this)`, we treat the caller as the
    // shard address. this is fine because the deck will delegatecall to this code in production.
    modifier asDeck() {
        vm.startPrank(shard);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        shard = vm.compile("src/shards/multicall.huff").create({value: 0});
        mockTarget = address(new MockTarget());
    }

    function testSingle() public asDeck {
        bytes memory payload = abi.encodeCall(MockTarget.succeeds, (42));
        mst.Call[] memory calls = new mst.Call[](1);
        calls[0] = mst.Call({target: mockTarget, value: 0, payload: payload});

        vm.expectCall(mockTarget, 0, payload, 1);
        (bool success,) = shard.call(mst.encodeCalls(true, calls));

        assertTrue(success);
    }

    function testSingleWithValue() public asDeck {
        vm.deal(shard, 42);

        bytes memory payload = abi.encodeCall(MockTarget.succeeds, (42));
        mst.Call[] memory calls = new mst.Call[](1);
        calls[0] = mst.Call({target: mockTarget, value: 42, payload: payload});

        vm.expectCall(mockTarget, 42, payload, 1);
        (bool success,) = shard.call{value: 42}(mst.encodeCalls(true, calls));

        assertTrue(success);
    }

    function testTwo() public asDeck {
        bytes memory payload = abi.encodeCall(MockTarget.succeeds, (42));
        mst.Call[] memory calls = new mst.Call[](2);
        calls[0] = mst.Call({target: mockTarget, value: 0, payload: payload});
        calls[1] = mst.Call({target: mockTarget, value: 0, payload: payload});

        vm.expectCall(mockTarget, 0, payload, 2);
        (bool success,) = shard.call(mst.encodeCalls(true, calls));

        assertTrue(success);
    }

    function testTwoWithValue() public asDeck {
        vm.deal(shard, 42 * 2);

        bytes memory payload = abi.encodeCall(MockTarget.succeeds, (42));
        mst.Call[] memory calls = new mst.Call[](2);
        calls[0] = mst.Call({target: mockTarget, value: 42, payload: payload});
        calls[1] = mst.Call({target: mockTarget, value: 42, payload: payload});

        vm.expectCall(mockTarget, 42, payload, 2);
        (bool success,) = shard.call{value: 42 * 2}(mst.encodeCalls(true, calls));

        assertTrue(success);
    }

    function testTwoMayFail() public asDeck {
        bytes memory payload = abi.encodeCall(MockTarget.fails, ());
        mst.Call[] memory calls = new mst.Call[](2);
        calls[0] = mst.Call({target: mockTarget, value: 0, payload: payload});
        calls[1] = mst.Call({target: mockTarget, value: 0, payload: payload});

        vm.expectCall(mockTarget, 0, payload, 2);
        (bool success,) = shard.call(mst.encodeCalls(true, calls));

        assertTrue(success);
    }

    function testTwoMayNotFail() public asDeck {
        bytes memory payload = abi.encodeCall(MockTarget.fails, ());
        mst.Call[] memory calls = new mst.Call[](2);
        calls[0] = mst.Call({target: mockTarget, value: 0, payload: payload});
        calls[1] = mst.Call({target: mockTarget, value: 0, payload: payload});

        (bool success,) = shard.call(mst.encodeCalls(false, calls));

        assertFalse(success);
    }

    function testOneFailsOneSucceedsMayFail() public asDeck {
        bytes memory payload = abi.encodeCall(MockTarget.fails, ());
        mst.Call[] memory calls = new mst.Call[](2);
        calls[0] = mst.Call({target: mockTarget, value: 0, payload: payload});
        calls[1] = mst.Call({target: mockTarget, value: 0, payload: abi.encodeCall(MockTarget.succeeds, (42))});

        (bool success,) = shard.call(mst.encodeCalls(true, calls));

        assertTrue(success);
    }

    function testOneFailsOneSucceedsMayNotFail() public asDeck {
        bytes memory payload = abi.encodeCall(MockTarget.fails, ());
        mst.Call[] memory calls = new mst.Call[](2);
        calls[0] = mst.Call({target: mockTarget, value: 0, payload: payload});
        calls[1] = mst.Call({target: mockTarget, value: 0, payload: abi.encodeCall(MockTarget.succeeds, (42))});

        (bool success,) = shard.call(mst.encodeCalls(false, calls));

        assertFalse(success);
    }

    function testFuzzSingle(address target, bytes4 selector, uint88 value) public asDeck {
        vm.assume(uint160(target) > 255);
        vm.deal(shard, value);
        bytes memory payload = abi.encodePacked(selector);
        mst.Call[] memory calls = new mst.Call[](1);
        calls[0] = mst.Call({target: target, value: value, payload: payload});

        (bool vibeCheck,) = target.call{value: value}(payload);
        if (vibeCheck) vm.expectCall(target, value, payload, 1);

        vm.deal(shard, value);

        (bool success,) = shard.call{value: value}(mst.encodeCalls(true, calls));
        assertTrue(success);
    }

    function testFuzzMulti(address target, bytes4 selector, uint8 value, uint8 iterations) public asDeck {
        vm.assume(uint160(target) > 255 && target != CREATE2_DEPLOYER);
        uint88 totalValue = uint88(value) * uint88(iterations);
        vm.deal(shard, totalValue);
        bytes memory payload = abi.encodePacked(selector);
        mst.Call[] memory calls = new mst.Call[](iterations);
        for (uint8 i = 0; i < iterations; i++) {
            calls[i] = mst.Call({target: target, value: value, payload: payload});
        }

        (bool vibeCheck,) = target.call{value: totalValue}(payload);
        if (vibeCheck) vm.expectCall(target, value, payload, iterations);
        else console.log(target);

        vm.deal(shard, totalValue);
        (bool success,) = shard.call{value: totalValue}(mst.encodeCalls(true, calls));

        assertTrue(success);
    }
}
