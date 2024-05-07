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

npx hardhat run scripts/theiaRouter/router.js --network

npx hardhat run scripts/protocol/deploy.js --network

npx hardhat run scripts/protocol/addOperator.js --network

```
## deployment router
```
npx hardhat run scripts/theiaRouter/router.js --network

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
npx hardhat erc20 --network manta_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network humanode_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000


npx hardhat run scripts/theiaRouter/setTokenConfig.js --network bsc_test
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network arb_test
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network sonic
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network sepolia
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network blast_sep
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network aeron_test
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network linea_sepolia
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network vanguard
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network manta_test
npx hardhat run scripts/theiaRouter/setTokenConfig.js --network humanode_test

npx hardhat run scripts/theiaRouter/setFeeConfig.js --network linea_sepolia
npx hardhat run scripts/theiaRouter/setFeeConfig.js --network vanguard
npx hardhat run scripts/theiaRouter/setFeeConfig.js --network manta_test
npx hardhat run scripts/theiaRouter/setFeeConfig.js --network humanode_test

npx hardhat run scripts/mock/deployMultiCall.js --network vanguard
npx hardhat run scripts/mock/deployMultiCall.js --network manta_test

npx hardhat run scripts/theiaRouter/genSQL.js --network vanguard
npx hardhat run scripts/theiaRouter/genSQL.js --network manta_test
npx hardhat run scripts/theiaRouter/genSQL.js --network humanode_test


```

