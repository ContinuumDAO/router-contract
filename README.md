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
npx hardhat verify --contract contracts/mock/USDT.sol:USDT  --network bsc_test <address> 

npx hardhat run scripts/theiaRouter/router.js --network arb_test

npx hardhat run scripts/protocol/verify.js --network arb_test

```
## deployment router
```
npx hardhat run scripts/theiaRouter/router.js --network mumbai

npx hardhat erc20 --network bsc_test name symbol decimals underlying 
```