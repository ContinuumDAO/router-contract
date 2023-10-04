const { expect } = require("chai");
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);

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


        it("MultiCall", async function () {
            await routerConfig.setChainConfig(97, "bsc_test", "0x7C6997Ae35cE2F440E65e35a80e595B17E3E2418", 2, 33587883, "{}")
            await routerConfig.setChainConfig(98, "bsc_test1", "0x7C6997Ae35cE2F440E65e35a80e595B17E3E2418", 2, 33587883, "{}")

            let ABI = [{ "inputs": [{ "internalType": "uint256", "name": "chainID", "type": "uint256" }], "name": "getChainConfig", "outputs": [{ "components": [{ "internalType": "uint256", "name": "ChainID", "type": "uint256" }, { "internalType": "string", "name": "BlockChain", "type": "string" }, { "internalType": "string", "name": "RouterContract", "type": "string" }, { "internalType": "uint64", "name": "Confirmations", "type": "uint64" }, { "internalType": "uint64", "name": "InitialHeight", "type": "uint64" }, { "internalType": "string", "name": "Extra", "type": "string" }], "internalType": "struct Structs.ChainConfig", "name": "", "type": "tuple" }], "stateMutability": "view", "type": "function" }]
            let contract = new web3.eth.Contract(ABI);
            let calldata1 = contract.methods.getChainConfig(97).encodeABI()
            let calldata2 = contract.methods.getChainConfig(98).encodeABI()

            let rtn = await routerConfig.multicall([calldata1, calldata2])
            // console.log(rtn)

        });
    });


});
