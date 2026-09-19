# 🛡️ Ethernaut Solutions

My solutions and security analysis for the **OpenZeppelin Ethernaut challenges**, built while learning smart contract security and auditing with Solidity, Foundry, and `cast`.

🔗 https://ethernaut.openzeppelin.com/

Ethernaut is a Web3 security wargame where each level contains a vulnerable smart contract that must be analyzed and exploited.

---

## Solved Challenges

| # | Challenge | Status |
|---:|---|:---:|
| 01 | [Fallback](./src/challenge-01_Fallback/README.md) | ✅ |
| 02 | [Fallout](./src/challenge-02_Fallout/README.md) | ✅ |
| 03 | [CoinFlip](./src/challenge-03_Coinflip/README.md) | ✅ |
| 04 | [Telephone](./src/challenge-04_Telephone/README.md) | ✅ |

> More challenges will be added as they are solved.

## What this repo covers

This repository focuses on learning smart contract security through:

* Vulnerability identification
* Exploit reasoning and attack paths
* Solidity-based attack contracts
* Foundry tests and Proofs of Concept
* `cast` for interacting with deployed contracts
* Live exploit verification on Ethereum Sepolia

Each challenge is documented from **vulnerability → attack path → PoC → impact → remediation**.

---

## What each challenge includes

Where applicable, each challenge contains:

* **README.md**

  * Challenge goal
  * Vulnerability
  * Attack path
  * Proof of Concept
  * Impact
  * Remediation
  * Audit takeaway
  * Live instance verification

* **Challenge contract**

  * Original Ethernaut challenge code

* **Foundry tests**

  * Local reproduction of the vulnerability
  * Exploit validation

* **Attack scripts**

  * Solidity-based exploit contracts
  * Automated interaction with live challenge instances

* **Cast commands**

  * Direct interaction with deployed contracts when a script/test is not required

---

## Learning Approach

The goal of this repository is not just to collect solutions.

For each challenge, I try to understand:

```text
Contract
   ↓
Identify privileged state / sensitive logic
   ↓
Find unexpected execution path
   ↓
Understand the vulnerability
   ↓
Build a reproducible exploit
   ↓
Test locally
   ↓
Verify against live instance
   ↓
Document the security takeaway
```

---

## Author

**Jash Bohare**

GitHub: https://github.com/Jash-Bohare

> Learning smart contract security one vulnerable contract at a time.
