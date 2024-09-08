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
npx hardhat run scripts/protocol/deploy.js --network

// npx hardhat run scripts/protocol/addOperator.js --network

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
npx hardhat erc20 --network fire_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network avac_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network rari_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network bArtio theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network lukso_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network core_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network holesky theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network bitlayer theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network cronos_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network base_sepolia theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network cfx_espace theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network opbnb_test theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network scroll_sepolia theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network morph_holesky theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network u2u_nebulas theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network polygon_amoy theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network mantle_sepolia theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network sei_atlantic theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000
npx hardhat erc20 --network soneium_minato theiaUSDT tUSDT 18 0x0000000000000000000000000000000000000000


npx hardhat run scripts/theiaRouter/genSQL.js --network
insert mysql

transfer native token to 0xEef3d3678E1E739C6522EEC209Bede0197791339

config c3caller-relayer network in server

npx hardhat run scripts/theiaRouter/setTokenConfig.js --network arb_test

npx hardhat run scripts/theiaRouter/setFeeConfig.js --network arb_test

config token icon in db:theia table:token_config

npx hardhat run scripts/mock/deployMultiCall.js --network vanguard
npx hardhat run scripts/mock/deployMultiCall.js --network manta_test
npx hardhat run scripts/mock/deployMultiCall.js --network fire_test
npx hardhat run scripts/mock/deployMultiCall.js --network avac_test
npx hardhat run scripts/mock/deployMultiCall.js --network rari_test
npx hardhat run scripts/mock/deployMultiCall.js --network bArtio
npx hardhat run scripts/mock/deployMultiCall.js --network lukso_test
npx hardhat run scripts/mock/deployMultiCall.js --network core_test
npx hardhat run scripts/mock/deployMultiCall.js --network holesky
npx hardhat run scripts/mock/deployMultiCall.js --network bitlayer
npx hardhat run scripts/mock/deployMultiCall.js --network cronos_test
npx hardhat run scripts/mock/deployMultiCall.js --network base_sepolia
npx hardhat run scripts/mock/deployMultiCall.js --network cfx_espace
npx hardhat run scripts/mock/deployMultiCall.js --network opbnb_test
npx hardhat run scripts/mock/deployMultiCall.js --network scroll_sepolia
npx hardhat run scripts/mock/deployMultiCall.js --network u2u_nebulas
npx hardhat run scripts/mock/deployMultiCall.js --network polygon_amoy
npx hardhat run scripts/mock/deployMultiCall.js --network mantle_sepolia
npx hardhat run scripts/mock/deployMultiCall.js --network sei_atlantic
npx hardhat run scripts/mock/deployMultiCall.js --network soneium_minato

```

## zksync
npm hardhat compile  --network zksync_sepolia