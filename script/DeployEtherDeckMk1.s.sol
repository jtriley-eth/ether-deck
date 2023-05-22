// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import "lib/forge-std/src/Script.sol";
import "lib/huff-runner/src/Deploy.sol";

using {compile} for Vm;
using {create} for bytes;

contract DeployEtherDeckMk1Script is Script {
    function run() public {
        bytes memory initcode = vm.compile("src/etherdeck-mk1.huff");
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        initcode.create({value: 0});

        vm.stopBroadcast();
    }
}
