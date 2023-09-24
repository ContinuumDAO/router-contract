const { expect } = require("chai");


describe("CtmConfig", function () {
    let owner
    let otherAccount
    let routerConfig


    async function deployConfig() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();

        const RouterConfig = await ethers.getContractFactory("RouterConfig");
        routerConfig = await RouterConfig.deploy();

        owner = _owner
        otherAccount = _otherAccount
    }


    beforeEach(async () => {
        await deployConfig()
    })


    describe("RounterConfig", function () {
        it("Deploy", async function () {
            expect(await routerConfig.hasRole("0x0000000000000000000000000000000000000000000000000000000000000000", owner.address)).to.equal(true)
            let configRole = await routerConfig.CONFIG_ROLE()
            expect(await routerConfig.hasRole(configRole, owner.address)).to.equal(true)

            expect(await routerConfig.hasRole(configRole, otherAccount.address)).to.equal(false)
        });
        it("ChainConfig", async function () {
            await routerConfig.setChainConfig(97, "bsc_test", "0x7C6997Ae35cE2F440E65e35a80e595B17E3E2418", 2, 33587883, "{}")
            

            console.log('getAllChainIDs', await routerConfig.getAllChainIDs())

            console.log('getAllChainConfig', await routerConfig.getAllChainConfig())
        });

    });


});
