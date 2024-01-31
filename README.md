# Router Contract

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```

## deployment protocol
```
npx hardhat verify --network bsc_test <address>
npx hardhat verify --contract contracts/mock/USDC.sol:USDC  --network bsc_test <address> 

npx hardhat run scripts/theiaRouter/router.js --network mumbai

npx hardhat run scripts/protocol/verify.js --network mumbai

```
## deployment router
```
npx hardhat run scripts/theiaRouter/router.js --network mumbai

npx hardhat erc20 --network bsc_test name symbol decimals underlying 

npx hardhat erc20 --network mumbai theiaUSDC tUSDC 6 0x0000000000000000000000000000000000000000
```