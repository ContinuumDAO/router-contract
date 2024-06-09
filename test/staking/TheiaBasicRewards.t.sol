// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Strings.sol";


import {USDC} from "contracts/mock/USDC.sol";
import {DAI} from "contracts/mock/DAI.sol";
import {WETH} from "contracts/mock/WETH.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {THEIA} from "contracts/routerV2/THEIA.sol";

import {TheiaCallData} from "contracts/mock/TheiaCallData.sol";
import {TheiaUUIDKeeper} from "contracts/routerV2/TheiaUUIDKeeper.sol";
import {FeeManager} from "contracts/routerV2/FeeManager.sol";
//import {IFeeManager} from "contracts/routerV2/IFeeManager.sol";
import {TheiaRouterConfig} from "contracts/routerV2/TheiaRouterConfig.sol";
import {TheiaRouter} from "contracts/routerV2/TheiaRouter.sol";
import {TheiaERC20} from "contracts/routerV2/TheiaERC20.sol";
import {ITheiaERC20} from "contracts/routerV2/ITheiaERC20.sol";
import {StagingVault} from "contracts/routerV2/StagingVault.sol";
import {IStagingVault} from "contracts/routerV2/IStagingVault.sol";
import {IVotingEscrow, VotingEscrow} from "contracts/routerV2/VeTHEIA.sol";
import {VeTHEIAProxy} from "contracts/routerV2/VeTHEIAProxy.sol";
import {TheiaRewards} from "contracts/routerV2/TheiaRewards.sol";
import {ITheiaRewards} from "contracts/routerV2/ITheiaRewards.sol";

import {C3SwapIDKeeper} from "lib/protocol/C3SwapIDKeeper.sol";
import {C3Caller} from "lib/protocol/C3Caller.sol";
import {IC3CallerProxy} from "lib/protocol/IC3Caller.sol";
import {C3CallerProxy} from "lib/protocol/C3CallerProxy.sol";



interface IC3CallerUpgradable is IC3CallerProxy {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

interface IVotingEscrowUpgradable is IVotingEscrow {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

interface ITheiaERC20Extended {
    function underlyingIsMinted() external view returns(bool);
}

contract SetUp is Test {
    using Strings for *;

    address admin;
    address gov;
    address user1;
    address treasury;
    address swapRouter;

    USDC usdc;
    DAI dai;
    WETH weth;
    VotingEscrow veImplV1;
    VeTHEIAProxy veTheiaProxy;
    IVotingEscrowUpgradable ve;

    address ADDRESS_ZERO = address(0);
    
    uint256 chainID;
    uint256 dappID = 1;

    string constant BASE_URI_V1 = "veTHEIA V1";

    TheiaCallData theiaCallData;
    FeeManager feeManager;
    TheiaUUIDKeeper theiaUUIDKeeper;
    TheiaRouterConfig theiaRouterConfig;
    TheiaRouter theiaRouter;
    StagingVault stagingVault;
    TheiaRewards theiaRewards;

    C3SwapIDKeeper c3SwapIDKeeper;
    C3Caller c3Caller;
    C3CallerProxy c3CallerProxy;
    IC3CallerUpgradable c3;

    THEIA theia;
    TheiaERC20 theiaETH;
    TheiaERC20 theiaUSDC;
    TheiaERC20 theiaDAI;
    TheiaERC20 theiaToken;

    uint256 THEIA_TS = 10_000_000 ether;

    uint256 initialBalUser = THEIA_TS/10;
    
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant MAXTIME = ONE_YEAR/2;
    uint256 constant WEEK = 1 weeks;

    uint256 constant BASE_EMISSION_RATE = 1 ether / 2000;

    uint256 usdcBal;
    uint256 daiBal;

    


    function setUp() public virtual {
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 privKey0 = vm.deriveKey(mnemonic, 0);
        uint256 privKey1 = vm.deriveKey(mnemonic, 1);
        uint256 privKey2 = vm.deriveKey(mnemonic, 2);
        uint256 privKey3 = vm.deriveKey(mnemonic, 3);
        admin = vm.addr(privKey0);
        gov = vm.addr(privKey1);
        user1 = vm.addr(privKey2);
        treasury = vm.addr(privKey3);

        usdc = new USDC();
        dai = new DAI();
        weth = new WETH();
        theiaCallData = new TheiaCallData();

        deployC3Caller();
        theiaUUIDKeeper = new TheiaUUIDKeeper(
            ADDRESS_ZERO,
            address(c3),
            admin,
            dappID
        );

        theiaRouter = new TheiaRouter(
            address(weth),
            address(theiaUUIDKeeper),
            address(theiaRouterConfig),
            address(feeManager),
            ADDRESS_ZERO,
            address(c3),
            admin,
            dappID
        );

        vm.startPrank(gov);
        theiaRouter.setDelay(0);
        feeManager.addFeeToken(address(usdc));
        theiaUUIDKeeper.addSupportedCaller(address(theiaRouter));
        vm.stopPrank();


        vm.startPrank(admin);

        theia = new THEIA(
            admin,
            gov,
            address(c3)
        );

        theiaETH = new TheiaERC20("theiaETHOD", "theiaETH", 18, address(weth), address(theiaRouter));
        theiaUSDC = new TheiaERC20("theiaUSDC", "theiaUSDC", 6, address(usdc), address(theiaRouter));  // token with underlying
        theiaDAI = new TheiaERC20("theiaDAI", "theiaDAI", 6, address(dai), address(theiaRouter)); // token with underlying
        theiaToken = new TheiaERC20("theiaToken", "theiaToken", 18, address(0), admin);  // mint/burn token
        theiaToken.setMinter(address(theiaRouter));
        skip(1 days);
        theiaToken.applyMinter();
        theiaUUIDKeeper.addSupportedCaller(address(theiaRouter));
        chainID = theiaRouter.cID();
        vm.stopPrank();

        vm.startPrank(address(theiaRouter));
        theiaUSDC.setMinter(address(theiaRouter));
        theiaDAI.setMinter(address(theiaRouter));
        theiaETH.setMinter(address(theiaRouter));
        skip(1 days);
        theiaUSDC.applyMinter();
        theiaDAI.applyMinter();
        theiaETH.applyMinter();
        vm.stopPrank();


        vm.startPrank(admin);
        veImplV1 = new VotingEscrow();

        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(theia),
            BASE_URI_V1
        );
        veTheiaProxy = new VeTHEIAProxy(address(veImplV1), initializerData);

        ve = IVotingEscrowUpgradable(address(veTheiaProxy));


        stagingVault = new StagingVault(
            admin,
            address(c3),
            1,
            gov,
            address(usdc),
            address(weth),
            address(ve)
        );


        // console.log('gov = ',gov);
        // console.log('theia = ',address(theia));
        // console.log('usdc = ',address(usdc));
        // console.log('swapRouter = ',swapRouter);
        // console.log('stagingVault = ', address(stagingVault));
        // console.log('ve = ',address(ve));
        // console.log('weth = ', address(weth));
        // console.log('*************************************************************************');

        theiaRewards = new TheiaRewards(
            0,
            gov,
            address(theia),
            address(usdc),
            swapRouter,
            address(stagingVault),
            address(ve),
            BASE_EMISSION_RATE,   // baseEmission rate
            address(weth)
        );

        vm.stopPrank();

        vm.startPrank(gov);

        ve.setUp(
            gov, 
            address(stagingVault), 
            address(theiaRewards),
            treasury
        );

        stagingVault.setUp(
            address(ve),
            address(theiaRewards)
        );

        vm.stopPrank();
        usdcBal = 100000*10**usdc.decimals();
        daiBal = 100000*10**dai.decimals();

        vm.startPrank(admin);
        usdc.transfer(user1, usdcBal);
        dai.transfer(user1, daiBal);

        theia.transfer(user1, initialBalUser);
        theia.transfer(address(theiaRewards), 100_000 ether);
        vm.stopPrank();


        vm.prank(user1);
        theia.approve(address(ve), initialBalUser);

    }


    function deployC3Caller() internal {

        c3SwapIDKeeper = new C3SwapIDKeeper(admin);

        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,address)",
            admin, 
            address(c3SwapIDKeeper)
        );

        c3Caller = new C3Caller();

        c3CallerProxy = new C3CallerProxy(
            address(c3Caller),
            initializerData
        );

        c3 = IC3CallerUpgradable(address(c3CallerProxy));

        assertEq(c3.getMPC(), admin);

        vm.startPrank(admin);
        c3SwapIDKeeper.addSupportedCaller(address(c3));
        c3.addOperator(address(c3));
        vm.stopPrank();

    }

    function getRevert(bytes calldata _payload) external pure returns(bytes memory) {
        return(abi.decode(_payload[4:], (bytes)));
    }

}

contract TestTheiaBasicRewards is SetUp {
    using Strings for *;
        
    modifier prankUser0() {
        vm.startPrank(admin);
        _;
        vm.stopPrank();
    }

    modifier prankUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
    }

    function test_vaultParams() public {
        //assertEq(stagingVault.mpc(), address(admin));

        address[] memory operators = c3.getAllOperators();
        assertEq(operators[0], address(admin));
        assertEq(operators[1], address(c3));

        assertEq(feeManager.getFeeTokenList()[0], address(usdc));
        assertEq(stagingVault.getTheiaRewards(), address(theiaRewards));
        assertEq(stagingVault.getVotingEscrow(), address(ve));
        assertEq(stagingVault.getLiquidityDelay(), 7 days);
    }

    function test_rewardsParams() public {
        assertEq(theiaRewards.getTheiaGov(), gov);
        assertEq(theiaRewards.getFeeToken(), address(usdc));
        assertEq(theiaRewards.getRewardToken(), address(theia));
    }

    function test_TheiaInitialMint() public {
        assertEq(theia.totalSupply(), THEIA_TS);
        assertEq(theia.balanceOf(user1), initialBalUser);
    }

    function test_stakingBasic() public {
        uint256 amount = 1000 ether;
        uint256 endpoint =  MAXTIME;
        vm.startPrank(user1);
        uint256 tokenId = ve.create_lock(amount, endpoint);
        vm.stopPrank();

        assertEq(tokenId, 1);
        uint256 vePower = IVotingEscrow(ve).balanceOfNFT(tokenId);
        console.log('Voting Power at start = ', vePower/1e18);
        assertEq(vePower/1e18, 986);

        skip(4 weeks);
        vePower = IVotingEscrow(ve).balanceOfNFT(tokenId);
        console.log('Voting Power after 4 weeks = ', vePower/1e18);
        assertEq(vePower/1e18, 832);

        uint256 rewards = theiaRewards.calculateBaseRewards(tokenId);
        console.log('Base rewards after 1 week = ', rewards/1e18, ' THEIA');
        assertEq(rewards/1e18, 12);

        skip(25 weeks); // 6 months

        vePower = IVotingEscrow(ve).balanceOfNFT(tokenId);
        console.log('Voting Power after 26 weeks = ', vePower/1e18);
        assertEq(vePower/1e18, 0);

        rewards = theiaRewards.calculateBaseRewards(tokenId);
        console.log('Base rewards after 26 weeks = ', rewards/1e18, ' THEIA');

        vm.prank(user1);
        uint256 rewardsReceived = theiaRewards.claimBaseRewards(tokenId);
        console.log('Rewards received = ', rewardsReceived/1e18);
        assertEq(rewardsReceived/1e18, 44);

    }
}
