// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import {USDC} from "contracts/mock/USDC.sol";
import {WETH} from "contracts/mock/WETH.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TheiaCallData} from "contracts/mock/TheiaCallData.sol";
import {TheiaUUIDKeeper} from "contracts/routerV2/TheiaUUIDKeeper.sol";
import {FeeManager} from "contracts/routerV2/FeeManager.sol";
import {TheiaRouterConfig} from "contracts/routerV2/TheiaRouterConfig.sol";
import {TheiaRouter} from "contracts/routerV2/TheiaRouter.sol";
import {TheiaERC20} from "contracts/routerV2/TheiaERC20.sol";

import {C3SwapIDKeeper} from "lib/protocol/C3SwapIDKeeper.sol";
import {C3Caller} from "lib/protocol/C3Caller.sol";
import {IC3CallerProxy} from "lib/protocol/IC3Caller.sol";
import {C3CallerProxy} from "lib/protocol/C3CallerProxy.sol";

interface IC3CallerUpgradable is IC3CallerProxy {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract SetUp is Test {
    using Strings for *;

    address admin;
    address gov;
    address user1;
    address user2;

    USDC usdc;
    WETH weth;

    address ADDRESS_ZERO = address(0);

    uint256 chainID;
    uint256 dappId = 1;

    FeeManager feeManager;
    TheiaCallData theiaCallData;
    TheiaUUIDKeeper theiaUUIDKeeper;
    TheiaRouterConfig theiaRouterConfig;
    TheiaRouter theiaRouter;

    C3SwapIDKeeper c3SwapIDKeeper;
    C3Caller c3Caller;
    C3CallerProxy c3CallerProxy;
    IC3CallerUpgradable c3;

    TheiaERC20 theiaETH;
    TheiaERC20 theiaUSDC;
    TheiaERC20 theiaToken;

    uint256 usdcBal;


    function setUp() public virtual {
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 privKey0 = vm.deriveKey(mnemonic, 0);
        uint256 privKey1 = vm.deriveKey(mnemonic, 1);
        uint256 privKey2 = vm.deriveKey(mnemonic, 2);
        uint256 privKey3 = vm.deriveKey(mnemonic, 3);
        admin = vm.addr(privKey0);
        gov = vm.addr(privKey1);
        user1 = vm.addr(privKey2);
        user2 = vm.addr(privKey3);

        usdc = new USDC();
        weth = new WETH();
        theiaCallData = new TheiaCallData();
        deployC3Caller();
        theiaUUIDKeeper = new TheiaUUIDKeeper(
            ADDRESS_ZERO,
            address(c3),
            admin,
            dappId
        );

       feeManager = new FeeManager(
            ADDRESS_ZERO,
            address(c3),
            admin,
            dappId
        );

        theiaRouterConfig = new TheiaRouterConfig(
            ADDRESS_ZERO,
            address(c3),
            admin,
            dappId
        );

        vm.startPrank(gov);
        theiaRouter.setDelay(0);
        feeManager.addFeeToken(address(usdc));
        theiaUUIDKeeper.addSupportedCaller(address(theiaRouter));
        vm.stopPrank();


        vm.startPrank(admin);
        theiaETH = new TheiaERC20("theiaETHOD", "theiaETH", 18, address(weth), address(theiaRouter));
        theiaUSDC = new TheiaERC20("theiaUSDC", "theiaUSDC", 18, address(usdc), address(theiaRouter));  // token with underlying
        theiaToken = new TheiaERC20("theiaToken", "theiaToken", 18, address(0), admin);  // mint/burn token
        theiaToken.setMinter(address(theiaRouter));
        skip(1 days);
        theiaToken.applyMinter();
        theiaUUIDKeeper.addSupportedCaller(address(theiaRouter));
        chainID = theiaRouter.cID();
        vm.stopPrank();

        vm.startPrank(address(theiaRouter));
        theiaUSDC.setMinter(address(theiaRouter));
        theiaETH.setMinter(address(theiaRouter));
        skip(1 days);
        theiaUSDC.applyMinter();
        theiaETH.applyMinter();
        vm.stopPrank();

        
        usdcBal = 100000*10**usdc.decimals();

        vm.prank(admin);
        usdc.transfer(user1, usdcBal);
        usdc.transfer(user2, usdcBal);

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

contract TestTheiaERC20 is SetUp {
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


    function test_Deploy() public {
        assertEq(theiaETH.owner(), address(theiaRouter));

        // address _gov = theiaRouter.getGovTHEIA();
        // assertEq(_gov, gov);

        address[] memory supported = theiaUUIDKeeper.getAllSupportedCallers();
        //console.log("No supported callers = ", supported.length);
        assertEq(supported[0], admin);
        assertEq(supported[1], address(theiaRouter));
        
        address[] memory operators = c3.getAllOperators();
        //console.log("No supported operators = ", operators.length);
        assertEq(operators[0], admin);
        assertEq(operators[1], address(c3));
    }

    function test_FeeChains() public {

        vm.startPrank(gov);
        theiaRouter.setFeeConfig(1, 56, 5*10**usdc.decimals(), 1);
        vm.stopPrank();

        uint256 swapFee = theiaRouter.getFeeConfig(1,56);
        assertEq(swapFee, 5*10**usdc.decimals());

        vm.startPrank(gov);
        theiaRouter.setFeeConfig(1, 56, 5*10**usdc.decimals(), 2);
        vm.stopPrank();

        swapFee = theiaRouter.getFeeConfig(1,56);
        assertEq(swapFee, 10*10**usdc.decimals());

        uint256 baseFee = theiaRouter.calcBaseSwapFee(1, 56);
        assertEq(baseFee, 10*10**usdc.decimals());

    }

    function test_convertDecimals() public {
        assertEq(theiaRouter.convertDecimals(1 ether, 18, 18), 1 ether);
        assertEq(theiaRouter.convertDecimals(1 ether, 18, 6), 1000000);
        assertEq(theiaRouter.convertDecimals(1000000, 6, 18), 1 ether);
        assertEq(theiaRouter.convertDecimals(1000000, 6, 0), 1);
        assertEq(theiaRouter.convertDecimals(1000000, 10, 8), 10000);
        assertEq(theiaRouter.convertDecimals(1000, 10, 5), 0);
    }

    function test_swapOutMintBurn() public {
        assertEq(theiaToken.isMinter(address(theiaRouter)), true);

        vm.startPrank(admin);
        theiaToken.mint(user1, 1 ether);
        vm.stopPrank();

        uint256 fee = 5*10**6;

        assertEq(theiaToken.balanceOf(user1), 1 ether);

        bytes32 swapID = theiaUUIDKeeper.calcSwapID(address(theiaRouter), address(theiaToken), user1, 1 ether, user1, 250);
        bytes memory callData = theiaCallData.genSwapInAutoCallData(address(theiaToken), 1 ether, user1, swapID, 18, address(theiaToken), fee);

        bytes32 uuid = c3SwapIDKeeper.calcCallerUUID(address(c3), 1, address(theiaRouter).toHexString(), 250.toString(), callData);
        
        //   await expect(routerV2.connect(otherAccount).swapOutAuto(theiaToken.target, amount.toString(), routerV2.target, otherAccount.address, theiaToken.target, 18, 250))
        //         .to.emit(routerV2, "LogSwapOut").withArgs(theiaToken.target, otherAccount.address, otherAccount.address.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)
        //         .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, routerV2.target, "250", routerV2.target.toLowerCase(), calldata)

        assertEq(theiaUUIDKeeper.isSupportedCaller(address(theiaRouter)), true);


        vm.startPrank(user1);
        usdc.approve(address(theiaRouter), fee);
        theiaRouter.swapOutAuto(address(theiaToken), 1 ether, address(theiaRouter), user1, address(theiaToken), 18, fee, 250);
        vm.stopPrank();

        //console.log("BAL AFTER swapOutAuto = ", theiaToken.balanceOf(user1));
        assertEq(theiaToken.balanceOf(user1), 0);

        // check the emitted events

        // await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", "", calldata))
        //         .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, true, uuid, chainID, "sourceTxHash", calldata, "0x0000000000000000000000000000000000000000000000000000000000000001")
        //         .to.emit(routerV2, "LogSwapIn").withArgs(theiaToken.target, otherAccount.address, swapID, amount.toString(), chainID, chainID, "sourceTxHash")

        vm.startPrank(admin);
        c3.execute(1, uuid, address(theiaRouter), chainID.toString(), "sourceTxHash", "", callData);
        vm.stopPrank();
        // check the emitted events

        //console.log("BAL AFTER execute = ", theiaToken.balanceOf(user1));
        assertEq(theiaToken.balanceOf(user1), 1 ether);

    }

    function test_Fallback() public {

        vm.startPrank(admin);
        theiaToken.mint(user1, 1 ether);
        vm.stopPrank();

        uint256 fee = 5*10**6;

        bytes32 swapID = theiaUUIDKeeper.calcSwapID(address(theiaRouter), address(theiaToken), user1, 1 ether, user1, 250);
        bytes memory callData = theiaCallData.genSwapInAutoCallData(address(theiaToken), 1 ether, user1, swapID, 18, address(theiaToken), fee);

        bytes32 uuid = c3SwapIDKeeper.calcCallerUUID(address(c3), 1, address(theiaRouter).toHexString(), 250.toString(), callData);
        
        string memory fallbackdata = "0xb121f51d00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000c404b97db9d9233bded7b9898c2c07a128ae0da6308be64ea4448a0917784a1c1217a95cd70000000000000000000000005322471a7e37ac2b8902cfcba84d266b37d811a000000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c80000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000005322471a7e37ac2b8902cfcba84d266b37d811a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
            
        vm.startPrank(admin);
        vm.expectRevert("C3Caller: dappID mismatch");
        c3.execute(2, uuid, address(theiaRouter), chainID.toString(), "sourceTxHash", fallbackdata, callData);
        
        c3.execute(1, uuid, address(theiaRouter), chainID.toString(), "sourceTxHash", fallbackdata, callData);
        vm.expectRevert("C3Caller: already completed");        
        c3.execute(1, uuid, address(theiaRouter), chainID.toString(), "sourceTxHash", fallbackdata, callData);
        vm.stopPrank();

        vm.startPrank(gov);
        theiaRouter.setFeeConfig(chainID, chainID, 50*10**usdc.decimals(), 1);
        vm.stopPrank();

        uint256 currentNonce = theiaUUIDKeeper.getCurrentNonce();
        assertEq(theiaUUIDKeeper.isSwapCompleted(swapID), true);
        
        vm.startPrank(admin);
        bytes32 newSwapID = theiaUUIDKeeper.registerSwapoutEvm(
            address(theiaToken),
            address(theiaRouter),
            1 ether,
            user1,
            250
        );
        vm.stopPrank();
        uint256 newNonce = theiaUUIDKeeper.getCurrentNonce();
        assertEq(newNonce, currentNonce+1);
        assertNotEq(newSwapID, swapID);
        assertEq(theiaUUIDKeeper.isSwapCompleted(newSwapID), false);
        vm.startPrank(address(c3));
        vm.expectRevert("Insufficient Fee");
        theiaRouter.swapInAuto(
            newSwapID,
            address(theiaToken),
            user1,
            1 ether,
            18,
            address(theiaToken),
            fee
        );
        assertEq(theiaUUIDKeeper.isSwapCompleted(newSwapID), false); // didn't complete

        theiaRouter.swapInAuto(
            newSwapID,
            address(theiaToken),
            user1,
            1 ether,
            18,
            address(theiaToken),
            10*fee
        );
        assertEq(theiaUUIDKeeper.isSwapCompleted(newSwapID), true); // did complete this time
        vm.stopPrank();
    }

    function test_SwapOutUnderlying() public {

        uint256 fee = 5*10**usdc.decimals();
        uint256 amount = 1000*10**usdc.decimals();

        vm.startPrank(user1);
        usdc.approve(address(theiaUSDC), 2000*10**usdc.decimals());
        theiaUSDC.deposit(2000*10**usdc.decimals());
        vm.stopPrank();

        (uint256 liqBeforeSwapout,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity before swapOut = ", liqBeforeSwapout, "USDC");
        assertEq(liqBeforeSwapout, 2000*10**usdc.decimals());

        bytes32 swapID = theiaUUIDKeeper.calcSwapID(address(theiaRouter), address(theiaUSDC), user1, amount, user1, 250);
        bytes memory callData = theiaCallData.genSwapInAutoCallData(address(theiaUSDC), amount, user1, swapID, 18, address(theiaUSDC), fee);

        bytes32 uuid = c3SwapIDKeeper.calcCallerUUID(address(c3), 1, address(theiaRouter).toHexString(), 250.toString(), callData);
        
        vm.startPrank(user1);
        usdc.approve(address(theiaRouter), 10000*10**usdc.decimals());
        uint256 balBeforeSwapout = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 before swapOut = ", balBeforeSwapout, "USDC");
        theiaRouter.swapOutAuto(address(theiaUSDC), amount, address(theiaRouter), user1, address(theiaUSDC), 18, fee, 250);
        uint256 balAfterSwapout = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 after swapOut = ", balAfterSwapout, "USDC");
        assertEq(balBeforeSwapout, balAfterSwapout+(fee+amount)/10**usdc.decimals());
        vm.stopPrank();

        // vm.startPrank(address(c3));
        // (bool success, bytes memory result) = address(theiaRouter).call(callData);
        // console.log("success = ", success);
        // console.log(string(result));
        // vm.stopPrank();

        vm.startPrank(admin);
        (uint256 liquidityBefore,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity before swapIn = ", liquidityBefore, "USDC");
        c3.execute(1, uuid, address(theiaRouter), chainID.toString(), "sourceTxHash", "", callData);
        uint256 balAfterSwapIn = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 after swapIn = ", balAfterSwapIn);
        uint256 balTheiaUSDC = theiaUSDC.balanceOf(user1)/10**18;
        console.log("TheiaUSDC bal of user1 after swapIn = ", balTheiaUSDC, "TheiaUSDC");
        assertEq(balBeforeSwapout, balAfterSwapIn+fee/10**usdc.decimals());
        (uint256 liquidityAfter,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity after swapIn = ", liquidityAfter, "USDC");
        assertEq(liquidityAfter, 2000*10**usdc.decimals());
        assertEq(liqBeforeSwapout, liquidityAfter);
        vm.stopPrank();


        uint256 currentNonce = theiaUUIDKeeper.getCurrentNonce();
        assertEq(theiaUUIDKeeper.isSwapCompleted(swapID), true);
        
        // the underlying liquidity is 2000 USDC, so we will use more than 80% of it
        amount = 1800*10**usdc.decimals();

        vm.startPrank(gov);
        theiaRouter.setFeeConfig(chainID, chainID, 5*10**usdc.decimals(), 1);
        vm.stopPrank();

        vm.startPrank(admin);
        bytes32 newSwapID = theiaUUIDKeeper.registerSwapoutEvm(
            address(theiaToken),
            address(theiaRouter),
            amount,
            user1,
            250
        );
        vm.stopPrank();

        (uint256 liquidity, uint256 dec) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("liquidity = ", liquidity, "amount = ", amount);
        fee = theiaRouter.getFee(chainID, chainID, liquidity, amount, true, dec);
        console.log("fee = ", fee/10**usdc.decimals(), "USDC");
        assertEq(fee, 28750000);

        callData = theiaCallData.genSwapInAutoCallData(address(theiaUSDC), amount, user1, newSwapID, 18, address(theiaUSDC), fee);

        uuid = c3SwapIDKeeper.calcCallerUUID(address(c3), 1, address(theiaRouter).toHexString(), 250.toString(), callData);
        
        vm.startPrank(user1);
        balBeforeSwapout = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 before swapOut = ", balBeforeSwapout, "USDC");
        theiaRouter.swapOutAuto(address(theiaUSDC), amount, address(theiaRouter), user1, address(theiaUSDC), 18, fee, 250);
        balAfterSwapout = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 after swapOut = ", balAfterSwapout, "USDC");
        assertEq(balBeforeSwapout, 1+balAfterSwapout+(fee+amount)/10**usdc.decimals());
        vm.stopPrank();

        vm.startPrank(admin);
        (liquidityBefore,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity before swapIn = ", liquidityBefore, "USDC");
        c3.execute(1, uuid, address(theiaRouter), chainID.toString(), "sourceTxHash", "", callData);
        balAfterSwapIn = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 after swapIn = ", balAfterSwapIn);
        balTheiaUSDC = theiaUSDC.balanceOf(user1)/10**18;
        console.log("TheiaUSDC bal of user1 after swapIn = ", balTheiaUSDC, "TheiaUSDC");
        assertEq(balBeforeSwapout, 1+balAfterSwapIn+fee/10**usdc.decimals());
        (liquidityAfter,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity after swapIn = ", liquidityAfter, "USDC");
        assertEq(liquidityAfter, 2000*10**usdc.decimals());
        assertEq(liqBeforeSwapout, liquidityAfter);
        vm.stopPrank();

    }

    function test_SwapOutUnderlyingFallback() public {

        uint256 fee = 5*10**usdc.decimals();
        uint256 amount = 3000*10**usdc.decimals();

        vm.startPrank(user1);
        usdc.approve(address(theiaUSDC), 2000*10**usdc.decimals());
        theiaUSDC.deposit(2000*10**usdc.decimals());   // amount > deposit
        vm.stopPrank();

        (uint256 liqBeforeSwapout,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity before swapOut = ", liqBeforeSwapout, "USDC");
        assertEq(liqBeforeSwapout, 2000*10**usdc.decimals());

        bytes32 swapID = theiaUUIDKeeper.calcSwapID(address(theiaRouter), address(theiaUSDC), user1, amount, user1, 250);
        bytes memory callData = theiaCallData.genSwapInAutoCallData(address(theiaUSDC), amount, user1, swapID, 18, address(theiaUSDC), fee);

        bytes32 uuid = c3SwapIDKeeper.calcCallerUUID(address(c3), 1, address(theiaRouter).toHexString(), 250.toString(), callData);
        
        bytes memory result = "0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001754523a696e73756666696369656e742062616c616e6365000000000000000000";
        bytes memory fallbackdata = c3.getFallbackCallData(1, callData, result);

        vm.startPrank(address(c3));
        (bool success, bytes memory res) = address(theiaRouter).call(callData);
        //console.log("success = ", success);
        string memory ret = string(this.getRevert(res));
        //console.log(ret);
        assertEq(success, false);
        assertEq(string(ret), "TR: not enough liquidity");
        vm.stopPrank();

        // vm.startPrank(admin);
        // vm.expectRevert("TR: not enough liquidity");
        // c3.execute(1, uuid, address(theiaRouter), chainID.toString(), "sourceTxHash", string(fallbackdata), callData);
        // vm.stopPrank();
    }

    function test_PartialRefund() public {

        uint256 fee = 5*10**usdc.decimals();
        uint256 amount = 1000*10**usdc.decimals();

        vm.startPrank(user2);  // user2 provides the underlying liquidity of 2000 USDC
        usdc.approve(address(theiaUSDC), 2000*10**usdc.decimals());
        theiaUSDC.deposit(2000*10**usdc.decimals());
        vm.stopPrank();

        (uint256 liqBeforeSwapout,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity before swapOut = ", liqBeforeSwapout/10**usdc.decimals(), "USDC");
        assertEq(liqBeforeSwapout, 2000*10**usdc.decimals());

        bytes32 swapID = theiaUUIDKeeper.calcSwapID(address(theiaRouter), address(theiaUSDC), user1, amount, user1, 250);
        bytes memory callData = theiaCallData.genSwapInAutoCallData(address(theiaUSDC), amount, user1, swapID, 18, address(theiaUSDC), fee);

        bytes32 uuid = c3SwapIDKeeper.calcCallerUUID(address(c3), 1, address(theiaRouter).toHexString(), 250.toString(), callData);
        // abi encoded "TR:insufficient balance"
        bytes memory result = "0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001754523a696e73756666696369656e742062616c616e6365000000000000000000";
        bytes memory fallbackdata = c3.getFallbackCallData(1, callData, result);


        vm.startPrank(user1);  // user1 does a swapOutAuto for 1000 USDC
        usdc.approve(address(theiaRouter), 10000*10**usdc.decimals());
        uint256 balBeforeSwapout = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 before swapOut = ", balBeforeSwapout, "USDC");
        theiaRouter.swapOutAuto(address(theiaUSDC), amount, address(theiaRouter), user1, address(theiaUSDC), 18, fee, 250);
        uint256 balAfterSwapout = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 after swapOut = ", balAfterSwapout, "USDC");
        assertEq(balBeforeSwapout, balAfterSwapout+(fee+amount)/10**usdc.decimals());
        vm.stopPrank();

        (uint256 liqBefore,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity before  = ", liqBefore/10**usdc.decimals(), "USDC");
        //assertEq(liqAfterBurn, 500*10**usdc.decimals());

        // theiaUSDC can transfer the underlying liquidity. We want to simulate another user taking the underlying
        assertEq(theiaUSDC.isMinter(address(theiaRouter)), true);
        vm.startPrank(address(theiaUSDC));
        IERC20(address(usdc)).transfer(user2, 2500*10**usdc.decimals());
        vm.stopPrank();

        (uint256 liqAfter,) = theiaRouter.getLiquidity(address(theiaUSDC));
        console.log("underlying liquidity after = ", liqAfter/10**usdc.decimals(), "USDC");
        assertEq(liqAfter, 500*10**usdc.decimals()); // now there is not enough liquidity for user1 to withdraw

        // we simulate the fallBack to the source chain for whatever reason

        vm.startPrank(admin);
        c3.c3Fallback(1, uuid, address(theiaRouter), chainID.toString(), "failTxHash", fallbackdata, result);
        vm.stopPrank();

        uint256 balAfterFallback = usdc.balanceOf(user1)/10**usdc.decimals();
        console.log("USDC bal of user1 after fallBack = ", balAfterFallback, "USDC");

        uint256 theiaUSDCbal = theiaUSDC.balanceOf(user1)/10**18;
        console.log("theiaUSDC balance = ", theiaUSDCbal);

    }

    // function test_tmp() public view {
    //     console.log(tx.gasprice);
    //     uint256 j;

    //     uint256 gasStart = gasleft();
    //     for(uint256 i=1;i<1000;i++) {
    //         j++;
    //     }

    //     uint256 gasSpent = gasStart - gasleft();
    //     console.log(gasSpent);
    // }
}

