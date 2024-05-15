const { expect } = require("chai");
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');
describe("TheiaConfig", function () {
    let owner
    let otherAccount
    let routerConfig


    async function deployConfig() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();

        const RouterConfig = await ethers.getContractFactory("TheiaRouterConfig");
        routerConfig = await RouterConfig.deploy("0x0000000000000000000000000000000000000000", 1);

        console.log(await routerConfig.cID())

        owner = _owner
        otherAccount = _otherAccount
    }


    beforeEach(async () => {
        await deployConfig()
    })


    describe("TheiaRounterConfig", function () {
        it("Deploy", async function () {
            expect(await routerConfig.hasRole("0x0000000000000000000000000000000000000000000000000000000000000000", owner.address)).to.equal(true)
            let configRole = await routerConfig.CONFIG_ROLE()
            expect(await routerConfig.hasRole(configRole, owner.address)).to.equal(true)

            expect(await routerConfig.hasRole(configRole, otherAccount.address)).to.equal(false)
        });

        it("TokenConfig", async function () {
            await routerConfig.setTokenConfig("ETH", 1, "0x1eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", 18, 1, "0x1111111111111111111111111111111111111111", "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
            await routerConfig.setTokenConfig("ETH", 31337, "0x2eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", 6, 1, "0x2111111111111111111111111111111111111111", "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")

            console.log(await routerConfig.getTokenConfigIfExist("ETH", 1))
            // console.log('getAllChainConfig', await routerConfig.getAllChainConfig())
        });
    });


});
