# <h1 align="center"> Hardhat x Foundry Template </h1>

**Template repository for getting started quickly with Hardhat and Foundry in one project**

![Github Actions](https://github.com/devanonon/hardhat-foundry-template/workflows/test/badge.svg)

### Comments for Solidity Test

- Use the plugin "better comments" and add a tag in settings.json:

```
  {
      "tag": "#",
      "color": "#2FD4DA",
      "strikethrough": false,
      "underline": false,
      "backgroundColor": "transparent",
      "bold": true,
      "italic": false
    }

```

### Deploy

```
yarn deploy --network {network_name}
npx hardhat setAllAddress --network {network_name}
```

### Getting Started

- Use Foundry:

```bash
forge install
forge test
```

- Use Hardhat:

```bash
npm install
npx hardhat test
```

### Features

- Write / run tests with either Hardhat or Foundry:

```bash
forge test
# or
npx hardhat test
```

- Use Hardhat's task framework

```bash
npx hardhat example
```

- Install libraries with Foundry which work with Hardhat.

```bash
forge install rari-capital/solmate # Already in this repo, just an example
```

### Notes

Whenever you install new libraries using Foundry, make sure to update your `remappings.txt` file by running `forge remappings > remappings.txt`. This is required because we use `hardhat-preprocessor` and the `remappings.txt` file to allow Hardhat to resolve libraries you install with Foundry.

### Pre-settings to run the protocol protection

- Deploy all contracts

```
yarn deploy --network {network_name}
```

- Set all address dependencies

```
npx hardhat setAllAddress --network {network_name}
```

- Approve protocol tokens in policyCenter

```
npx hardhat approvePolicyCenter --network {network_name}
``
```

- Mint MockUSDC to MockExchange
