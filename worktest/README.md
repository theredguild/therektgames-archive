# Worktest

Worktest for a web3 security researcher hiring process.

## Context & goal

There's a `MultiSig` contract that allows you to execute operations.

To execute them, the signatures of authorized operators are required.

The worktest's goal is that you can execute an operation as **a single** one of the authorized signers, without needing the other signatures.

## Requirements

- [Foundry](https://book.getfoundry.sh/), for testing.
- [Python](https://www.python.org/downloads/), for off-chain generation and usage of test private keys.

## Setup

1. Clone the repository
2. Install dependencies

```
pip install -r requirements.txt
```

3. Make sure the whole setup is OK

```
forge test
```

4. Find the flaw in the `MultiSig` contract, and modify the test file `MultiSig.t.sol` such that you accomplish the goal.
