# 🏛️ Simple DAO Governance System

A decentralized autonomous organization (DAO) smart contract built on Stacks blockchain that enables transparent governance through token staking, proposal creation, and community voting.

## ✨ Features

- 🔒 **Token Staking**: Stake tokens to participate in governance
- 📝 **Proposal Creation**: Submit proposals with minimum stake requirement
- 🗳️ **Democratic Voting**: Vote on proposals with your staked tokens
- ⚡ **Automatic Execution**: Execute passed proposals after delay period
- 📊 **Transparent Governance**: All votes and proposals are on-chain
- 🛡️ **Security Controls**: Configurable parameters and ownership controls

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

## 📋 Contract Functions

### 💰 Staking Functions

#### `stake-tokens`
Stake tokens to participate in governance.
```clarity
(contract-call? .Simple-DAO-Governance-System stake-tokens u1000)
```

#### `unstake-tokens`
Withdraw your staked tokens.
```clarity
(contract-call? .Simple-DAO-Governance-System unstake-tokens u500)
```

### 📝 Proposal Functions

#### `create-proposal`
Create a new governance proposal (requires minimum stake).
```clarity
(contract-call? .Simple-DAO-Governance-System create-proposal 
  "Fund New Project" 
  "Allocate 10000 STX for community development" 
  (some 'SP1EXAMPLE...) 
  u10000)
```

#### `vote-on-proposal`
Vote on an active proposal with your staked tokens.
```clarity
(contract-call? .Simple-DAO-Governance-System vote-on-proposal u1 true)
```

#### `execute-proposal`
Execute a passed proposal after the execution delay.
```clarity
(contract-call? .Simple-DAO-Governance-System execute-proposal u1)
```

### 📊 Read-Only Functions

#### `get-proposal-info`
Get detailed information about a proposal.
```clarity
(contract-call? .Simple-DAO-Governance-System get-proposal-info u1)
```

#### `get-user-stake`
Check a user's current stake amount.
```clarity
(contract-call? .Simple-DAO-Governance-System get-user-stake 'SP1EXAMPLE...)
```

#### `get-proposal-status`
Get the current status of a proposal.
```clarity
(contract-call? .Simple-DAO-Governance-System get-proposal-status u1)
```

#### `get-governance-stats`
Get current governance configuration.
```clarity
(contract-call? .Simple-DAO-Governance-System get-governance-stats)
```

## ⚙️ Configuration

### Default Parameters

- **Minimum Stake**: 1000 tokens
- **Voting Period**: 1008 blocks (~1 week)
- **Execution Delay**: 144 blocks (~1 day)
- **Quorum**: 30% of total staked tokens

### 🔧 Admin Functions (Contract Owner Only)

#### `set-min-stake`
Update minimum stake requirement.
```clarity
(contract-call? .Simple-DAO-Governance-System set-min-stake u2000)
```

#### `set-voting-period`
Update voting period duration.
```clarity
(contract-call? .Simple-DAO-Governance-System set-voting-period u2016)
```

#### `set-execution-delay`
Update execution delay period.
```clarity
(contract-call? .Simple-DAO-Governance-System set-execution-delay u288)
```

#### `set-quorum-percentage`
Update required quorum percentage.
```clarity
(contract-call? .Simple-DAO-Governance-System set-quorum-percentage u40)
```

## 🔄 Governance Workflow

1. **💰 Stake Tokens**: Users stake tokens to participate
2. **📝 Create Proposal**: Stakers create proposals with details and funding requests
3. **🗳️ Voting Period**: Community votes for/against proposals
4. **⏱️ Execution Delay**: Passed proposals wait for execution delay
5. **⚡ Execute**: Anyone can execute passed proposals
6. **💸 Fund Transfer**: Approved funds are automatically transferred

## 🛡️ Security Features

- Minimum stake requirements prevent spam proposals
- Execution delays allow for review period
- Quorum requirements ensure adequate participation
- Vote weight proportional to stake amount
- Immutable voting records on-chain

## 📈 Proposal States

- **Active**: Currently accepting votes
- **Passed**: Met quorum and majority approval
- **Rejected**: Failed to meet requirements
- **Executed**: Successfully executed and funds transferred

## 🧪 Testing

Run the test suite with:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For questions or issues, please open a GitHub issue or reach out to the community.

---

**Built with ❤️ on Stacks blockchain**
