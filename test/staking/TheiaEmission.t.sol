// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {THEIA} from "contracts/routerV2/THEIA.sol";

interface IERC20 {
    function decimals() external view returns(uint8);
    function balanceOf(address) external view returns(uint256);
    function transfer(address recipient, uint256 amount) external returns(bool success);
}

contract SetUp is Test {

    address admin;
    address gov;
    address user1;

    uint256 fac;

    THEIA theia;

    function setUp() public virtual {
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 privKey0 = vm.deriveKey(mnemonic, 0);
        uint256 privKey1 = vm.deriveKey(mnemonic, 1);
        uint256 privKey2 = vm.deriveKey(mnemonic, 2);
        admin = vm.addr(privKey0);
        gov = vm.addr(privKey1);
        user1 = vm.addr(privKey2);

        // set to 0x until we have a working c3Caller testnet
        address c3CallerContract = address(0);

        theia = new THEIA(admin, gov, c3CallerContract);

    }

}
    
contract TheiaEmissionTest is SetUp {

    uint256 constant internal SECS_PER_YEAR = 3600*(365*24 + 6);

    function setUp() public override {
        super.setUp();
    }

// TESTS

    function test_TheiaControl() public {
        assertEq(theia.isAdmin(admin), true);
        assertEq(theia.isAdmin(gov), false);
        assertEq(theia.isGov(gov), true);
    }

    function test_TheiaInitialMint() public {
        assertEq(theia.balanceOf(admin), 10000000 ether);
    }

    function test_TheiaEmission() public {

        uint256 emission;

        console.log("After 0 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 10000000);

        skip(SECS_PER_YEAR);

        console.log("After 1 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 5000000);

        skip(SECS_PER_YEAR);

        console.log("After 2 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 3333333);
        skip(SECS_PER_YEAR);

        console.log("After 3 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 2500000);

        skip(SECS_PER_YEAR);

        console.log("After 4 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 2000000);

        skip(SECS_PER_YEAR);

        console.log("After 5 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 1666666);

        skip(SECS_PER_YEAR);

        console.log("After 6 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 1428571);

        skip(SECS_PER_YEAR);

        console.log("After 7 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 1250000);

        skip(SECS_PER_YEAR);

        console.log("After 8 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 1111111);

        skip(SECS_PER_YEAR);

        console.log("After 9 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 1000000);

        skip(SECS_PER_YEAR);

        console.log("After 10 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 909090);

        skip(10*SECS_PER_YEAR);

        console.log("After 20 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 476190);

        skip(30*SECS_PER_YEAR);

        console.log("After 50 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 196078);

        skip(50*SECS_PER_YEAR);

        console.log("After 100 years");
        emission = SECS_PER_YEAR*theia.tokenEmission()/1e18;
        console.log(emission);
        assertEq(emission, 99009);
    }

    function test_TheiaAlloc() public {

        uint256 alloc;

        skip(SECS_PER_YEAR);
        console.log("After 1 year");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 6931472);

        skip(SECS_PER_YEAR);
        console.log("After 2 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 4054651);

        skip(SECS_PER_YEAR);
        console.log("After 3 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 2876820);

        skip(SECS_PER_YEAR);
        console.log("After 4 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 2231435);

        skip(SECS_PER_YEAR);
        console.log("After 5 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 1823215);

        skip(SECS_PER_YEAR);
        console.log("After 6 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 1541506);

        skip(SECS_PER_YEAR);
        console.log("After 7 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 1335314);

        skip(SECS_PER_YEAR);
        console.log("After 8 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 1177830);

        skip(SECS_PER_YEAR);
        console.log("After 9 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 1053605);

        skip(SECS_PER_YEAR);
        console.log("After 10 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 953101);

        skip(SECS_PER_YEAR);
        console.log("After 11 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 870113);

        skip(SECS_PER_YEAR);
        console.log("After 12 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 800427);

        skip(SECS_PER_YEAR);
        console.log("After 13 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 741079);

        skip(SECS_PER_YEAR);
        console.log("After 14 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 689928);

        skip(SECS_PER_YEAR);
        console.log("After 15 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 645385);

        skip(SECS_PER_YEAR);
        console.log("After 16 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 606246);

        skip(SECS_PER_YEAR);
        console.log("After 17 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 571584);

        skip(SECS_PER_YEAR);
        console.log("After 18 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 540672);

        skip(SECS_PER_YEAR);
        console.log("After 19 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 512932);

        skip(SECS_PER_YEAR);
        console.log("After 20 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 487901);

    }

    function test_TheiaAlloc10Years() public {

        uint256 alloc;

        skip(10*SECS_PER_YEAR);
        console.log("After 10 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 23978954);
    }

    function test_TheiaAlloc20Years() public {

        uint256 alloc;

        skip(20*SECS_PER_YEAR);
        console.log("After 20 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 30445227);
    }

    function test_TheiaAlloc50Years() public {

        uint256 alloc;

        skip(50*SECS_PER_YEAR);
        console.log("After 50 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 39318259);
    }

    function test_TheiaAlloc100Years() public {

        uint256 alloc;

        skip(100*SECS_PER_YEAR);
        console.log("After 100 years");

        vm.prank(gov);
        alloc = theia.tokenAlloc()/1e18;
        console.log(alloc);
        assertEq(alloc, 46151209);
    }

}
