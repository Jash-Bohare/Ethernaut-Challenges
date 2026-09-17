# Ethernaut Challenge 01 — Fallback

## Goal

The challenge is solved when:

1. Ownership is claimed.
2. The contract balance is reduced to `0`.

**Instance:**

```text
0x1fE0354057e5187948A681f37835F80707b4EF7C
```

## Vulnerability

The contract contains two paths that can modify `owner`.

`contribute()` attempts to enforce a contribution-based ownership transfer:

```solidity
if (contributions[msg.sender] > contributions[owner]) {
    owner = msg.sender;
}
```

However, the `receive()` function directly assigns ownership:

```solidity
receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
}
```

An attacker can therefore bypass the contribution comparison by:

1. Making any non-zero contribution.
2. Sending ETH directly to the contract.
3. Triggering `receive()`.
4. Becoming the owner.
5. Calling `withdraw()` to drain the contract.

The attacker does **not** need to exceed the original owner's `1000 ETH` contribution.

## Attack Path

```text
contribute(1 wei)
      ↓
contributions[attacker] > 0
      ↓
direct ETH transfer
      ↓
receive()
      ↓
owner = attacker
      ↓
withdraw()
      ↓
contract balance = 0
```

## Proof of Concept

A Foundry PoC reproducing the complete attack is available in:

```text
test/challenge-01_Fallback_Test/Fallback.t.sol
```

Run:

```bash
forge test --mt testFallbackAttack -vvv
```

The test verifies:

* Initial ownership
* Attacker contribution
* Ownership takeover through `receive()`
* Successful execution of `withdraw()`
* Contract balance reduced to `0`
* ETH received by the attacker

## Impact

**Severity: Critical**

An unprivileged user can take ownership of the contract and subsequently drain all ETH held by it.

This bypasses the intended ownership-transfer logic and compromises the contract's entire ETH balance.

## Remediation

`receive()` should not modify the privileged `owner` state.

Remove the ownership assignment:

```solidity
owner = msg.sender;
```

Ownership should only be transferred through an explicitly authorized mechanism that enforces the intended ownership invariant.

## Audit Takeaway

When auditing privileged state, inspect **every execution path that can modify it**, including:

* `receive()`
* `fallback()`
* public/external functions
* initialization functions
* internal state-changing functions

The core issue here is an **inconsistent security invariant**: `contribute()` restricts ownership transfer, while `receive()` provides an unrestricted alternative path.
