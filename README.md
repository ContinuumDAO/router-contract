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
npx hardhat verify --network sepolia 0x79fbCC00Bd1E749452bEc9A78d5f07Cd69c6EA58 theiaCTM tCtm 18 0x0000000000000000000000000000000000000000 0x4Aabbec02B2196D9149e7699210b8215AB1005F1
npx hardhat verify --network sepolia 0xCB0E6c371B35fc4c62e6DE746C8CA00C007030aD theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000 0x4Aabbec02B2196D9149e7699210b8215AB1005F1
npx hardhat verify --network bsc_test 0xf7539A4F14B9D713e016D3E98AEAe4207ac18Db2 theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000 0x53f5CdB1BDf9fA49e061FE28A9a3F38eB02ed038

npx hardhat run scripts/theiaRouter/router.js --network arb_test

npx hardhat run scripts/protocol/verify.js --network arb_test

```
## deployment router
```
npx hardhat run scripts/theiaRouter/router.js --network mumbai

npx hardhat erc20 --network bsc_test name symbol decimals underlying 

npx hardhat erc20 --network arb_test theiaUSDT tUSDT 6 0xbF5356AdE7e5F775659F301b07c4Bc6961044b11
npx hardhat erc20 --network arb_test theiaCTM tCtm 18 0x2A2a5e1e2475Bf35D8F3f85D8C736f376BDb1C02
npx hardhat erc20 --network bsc_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network bsc_test theiaCTM tCtm 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network sonic theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network sepolia theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network sepolia theiaCTM tCtm 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network blast_sep theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network blast_sep theiaCTM tCtm 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network aeron_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network linea_sepolia theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network vanguard theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000


npx hardhat run scripts/theiaRouter/setTokenConfig.js --network bsc_test
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network arb_test
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network sonic
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network sepolia
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network blast_sep
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network aeron_test
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network linea_sepolia
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network vanguard

npx hardhat run scripts/theiaRouter/setFeeConfig.js --network linea_sepolia
npx hardhat run scripts/theiaRouter/setFeeConfig.js --network vanguard

npx hardhat run scripts/theiaRouter/genSQL.js --network vanguard

npx hardhat run scripts/mock/deployMultiCall.js --network vanguard
```

