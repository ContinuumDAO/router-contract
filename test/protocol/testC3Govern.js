const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { Web3, eth } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');

describe("protocal", function () {
    let owner
    let otherAccount
    let c3Caller
    let c3SwapIDKeeper
    let c3CallerProxy
    let c3Governor


    async function deployC3Govern() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();

        const C3SwapIDKeeper = await ethers.getContractFactory("contracts/protocol/C3UUIDKeeper.sol:C3UUIDKeeper");
        c3SwapIDKeeper = await C3SwapIDKeeper.deploy();

        const C3Caller = await ethers.getContractFactory("contracts/protocol/C3Caller.sol:C3Caller");
        c3Caller = await C3Caller.deploy(c3SwapIDKeeper.target);

        const C3CallerProxy = await ethers.getContractFactory("C3CallerProxy");
        c3CallerProxy = await upgrades.deployProxy(C3CallerProxy, [c3Caller.target], { initializer: 'initialize', kind: 'uups' });

        const C3Governor = await ethers.getContractFactory("C3Governor");
        c3Governor = await C3Governor.deploy();

        await c3SwapIDKeeper.addOperator(c3Caller.target)

        await c3Caller.addOperator(c3CallerProxy.target)

        owner = _owner
        otherAccount = _otherAccount
    }


    beforeEach(async () => {
        await deployC3Govern()
    })

    describe("protocal.C3Caller", function () {
        it("sendParams", async function () {
            let data = "0x0000000000000000000000000000000000000000000000000000000000066eee000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000002a3078303834323634333943333633466134324265623241633962313737306131313530366246373839380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000249870d7fe000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb9226600000000000000000000000000000000000000000000000000000000"
            let nonce = "0x0000000000000000000000000000000000000000000000000000000000000001"
            await expect(c3Governor.sendParams(data, nonce)).to.emit(c3Governor, "NewProposal").withArgs(nonce).
                to.emit(c3Governor, "C3GovernorLog").withArgs(nonce, "421614", "0x08426439C363Fa42Beb2Ac9b1770a11506bF7898", "0x9870d7fe000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266")

            // console.log(await c3Governor.getProposalData(nonce, 0))
        });


    });
});