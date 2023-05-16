// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import {DeckTools as dt} from "src/util/DeckTools.sol";
import "lib/forge-std/src/Script.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract SetAuthScript is Script {
    function run() public {
        // SET THESE
        address deck;
        uint256 id;
        address signer;
        bool authorized;

        uint64 deadline = uint64(block.timestamp) + 3600;
        uint256 pk = vm.envUint("PRIVATE_KEY");

        bytes memory payload = dt.encodeSetAuth(signer, authorized);
        bytes32 hash = dt.hashSyscall(
            id,
            deck,
            0,
            deadline,
            payload,
            block.chainid
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = abi.encodePacked(v, r, s);

        (bool success, ) = deck.call(
            dt.encodeSyscall(id, deck, 0, deadline, payload, sigs)
        );

        require(success);

        vm.stopBroadcast();
    }
}
