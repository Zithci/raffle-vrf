# Provably Random Raffle Contract

A provably fair, decentralized raffle smart contract built with Solidity and Foundry. Uses **Chainlink VRF V2.5** for verifiable randomness and **Chainlink Automation** for trustless, time-based winner selection.

## Table of Contents

- [About](#about)
- [How It Works](#how-it-works)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Deploy](#deploy)
  - [Testing](#testing)
- [Deployment to a Testnet](#deployment-to-a-testnet)
  - [Setup](#setup)
  - [Deploy to Sepolia](#deploy-to-sepolia)
  - [Register Chainlink Automation](#register-chainlink-automation)
- [Architecture](#architecture)
  - [Contract Overview](#contract-overview)
  - [Chainlink VRF Flow](#chainlink-vrf-flow)
  - [State Machine](#state-machine)
- [Scripts](#scripts)
- [Estimated Gas](#estimated-gas)
- [Built With](#built-with)
- [Acknowledgements](#acknowledgements)

## About

On-chain lotteries face a fundamental problem: blockchains are deterministic, so there's no native source of randomness. Using `block.timestamp` or `block.prevrandao` is insecure — miners/validators can influence these values.

This contract solves that by integrating **Chainlink VRF (Verifiable Random Function)**, which provides cryptographically proven random numbers that even the node operators generating them cannot manipulate. Combined with **Chainlink Automation**, the entire raffle lifecycle — from entry to winner selection — runs autonomously without any human intervention.

**Key features:**
- Verifiably random winner selection via Chainlink VRF V2.5
- Automated, time-based draws via Chainlink Automation (Keepers)
- Entrance fee to participate
- Winner receives the entire prize pool
- State machine pattern prevents re-entrancy during draws

## How It Works

1. Players enter the raffle by calling `enterRaffle()` and paying the entrance fee.
2. After a configurable time interval, Chainlink Automation triggers `performUpkeep()`.
3. `performUpkeep()` requests a random number from the Chainlink VRF Coordinator.
4. Chainlink VRF calls back `fulfillRandomWords()` with a verified random number.
5. The contract uses `randomWord % players.length` to pick a winner.
6. The winner receives the entire ETH balance of the contract.
7. The raffle resets and a new round begins.

## Getting Started

### Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [foundry](https://getfoundry.sh/)

### Quickstart

```bash
git clone https://github.com/Zithci/foundry-smart-contract-lottery
cd foundry-smart-contract-lottery
forge build
```

## Usage

### Deploy

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Testing

Run the full test suite:

```bash
forge test
```

Run tests with verbosity for detailed traces:

```bash
forge test -vvvv
```

Run a specific test:

```bash
forge test --match-test testRaffleRevertsWhenYouDontPayEnough
```

Get test coverage:

```bash
forge coverage
```

## Deployment to a Testnet

### Setup

1. **Environment variables** — Create a `.env` file:

```
SEPOLIA_RPC_URL=<your_alchemy_or_infura_sepolia_rpc>
PRIVATE_KEY=<your_wallet_private_key>
ETHERSCAN_API_KEY=<your_etherscan_api_key>
```

> **⚠️ IMPORTANT:** Never commit your `.env` file. It's already in `.gitignore`. For production, use `cast wallet` or a hardware wallet — never raw private keys.

2. **Load environment variables:**

```bash
source .env
```

3. **Chainlink VRF Subscription** — Go to [vrf.chain.link](https://vrf.chain.link/) and:
   - Create a new subscription on Sepolia
   - Fund it with LINK
   - Note your subscription ID

### Deploy to Sepolia

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

After deployment:
- Add the deployed contract address as a consumer on your VRF subscription at [vrf.chain.link](https://vrf.chain.link/)

### Register Chainlink Automation

1. Go to [automation.chain.link](https://automation.chain.link/)
2. Register a new upkeep
3. Select **Custom logic**
4. Enter your deployed contract address
5. Set your preferred gas limit and funding amount

Once registered, Chainlink nodes will automatically call `performUpkeep()` when `checkUpkeep()` returns `true` (i.e., enough time has passed, the raffle has players, and the raffle is in the OPEN state).

## Architecture

### Contract Overview

```
src/
└── Raffle.sol          — Main raffle contract

script/
├── DeployRaffle.s.sol  — Deployment script
└── HelperConfig.s.sol  — Network-specific configuration (Sepolia, Anvil)

test/
└── unit/
    └── RaffleTest.t.sol — Unit tests
```

### Chainlink VRF Flow

```
┌────────────┐    checkUpkeep()     ┌──────────────┐
│  Chainlink  │ ──────────────────► │              │
│  Automation │                     │    Raffle    │
│  (Keeper)   │ ◄────── true ────── │   Contract   │
└─────┬───────┘                     └──────┬───────┘
      │                                    │
      │  performUpkeep()                   │ requestRandomWords()
      │                                    ▼
      │                            ┌───────────────┐
      │                            │   Chainlink    │
      │                            │     VRF        │
      │                            │  Coordinator   │
      │                            └───────┬───────┘
      │                                    │
      │                                    │ fulfillRandomWords()
      │                                    ▼
      │                            ┌───────────────┐
      │                            │ Winner picked  │
      │                            │ ETH transferred │
      │                            │ Raffle resets   │
      └────────────────────────────┴───────────────┘
```

### State Machine

The contract uses a `RaffleState` enum to prevent conflicting operations:

```
  OPEN ──────────────────────► CALCULATING
   ▲      (performUpkeep)          │
   │                               │
   │                               │ (fulfillRandomWords)
   │                               │
   └───────────────────────────────┘
         Raffle resets to OPEN
```

- **OPEN** — Players can enter. `checkUpkeep()` monitors if conditions are met.
- **CALCULATING** — A random number has been requested. No new entries allowed. Waiting for VRF callback.

## Scripts

| Script | Purpose |
|--------|---------|
| `DeployRaffle.s.sol` | Deploys Raffle contract with network-appropriate config |
| `HelperConfig.s.sol` | Returns constructor args per chain (Sepolia uses live VRF Coordinator; Anvil deploys mocks) |

## Estimated Gas

| Function | Gas |
|----------|-----|
| `enterRaffle` | ~51,000 |
| `performUpkeep` | ~72,000 |
| `fulfillRandomWords` | ~82,000 |

> Gas estimates are approximate and depend on the number of players.

## Built With

- [Solidity](https://docs.soliditylang.org/) — Smart contract language
- [Foundry](https://getfoundry.sh/) — Development framework (Forge, Cast, Anvil, Chisel)
- [Chainlink VRF V2.5](https://docs.chain.link/vrf) — Verifiable random number generation
- [Chainlink Automation](https://docs.chain.link/chainlink-automation) — Decentralized contract execution

## Acknowledgements

- [Patrick Collins](https://www.youtube.com/@PatrickAlphaC) — Cyfrin Updraft Foundry Course
- [Chainlink Documentation](https://docs.chain.link/)
- [Foundry Book](https://book.getfoundry.sh/)
