// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployMSC} from "../../script/DeployMSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MSC} from "../../src/MSC.sol";
import {MSCEngine} from "../../src/MSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract MSCEngineTest is Test {
    DeployMSC deployMSC;
    MSC msc;
    MSCEngine mscEngine;
    HelperConfig config;
    address link;
    address linkPriceFeed;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint public constant STARTING_BALANCE = 10000e18;

    function setUp() public {
        deployMSC = new DeployMSC();
        (msc, mscEngine, config) = deployMSC.run();
        (linkPriceFeed, link, ) = config.activeNetworkConfig();

        ERC20Mock(link).mint(USER, STARTING_BALANCE);

        vm.startPrank(USER);
        ERC20Mock(link).approve(address(mscEngine), STARTING_BALANCE);
        msc.approve(address(mscEngine), STARTING_BALANCE);
        vm.stopPrank();
    }

    ///////// GETTERS TESTS /////////

    function testGetUSDValue() public view {
        uint256 usdValue = mscEngine.getUSDValue(link, 1e18);
        assertEq(150 * 1e18, usdValue);
    }

    function testGetTokenAmountForUSD() public view {
        uint256 tokenAmount = mscEngine.getTokenAmountForUSD(link, 1500e18);
        assertEq(10 * 1e18, tokenAmount);
    }

    function testGetUserInfo() public {
        vm.startPrank(USER);

        mscEngine.depositAndMint(link, 1e18, 100e18);
        (uint callateralValue, uint debt) = mscEngine.getUserInfo(USER);
        assertEq(150 * 1e18, callateralValue);
        assertEq(100e18, debt);

        vm.stopPrank();
    }

    function testAccountCollateralBalance() public {
        vm.startPrank(USER);

        mscEngine.depositCollateral(link, 1e18);
        uint balance = mscEngine.getAccountCollateral(USER);
        assertEq(150e18, balance);

        vm.stopPrank();
    }

    ////////// DEPOSIT TESTS //////////

    function testRevertDepositIfTokenNotAllowed() public {
        vm.startPrank(USER);

        vm.expectRevert(bytes("MSCEngine: Token not allowed"));
        mscEngine.depositCollateral(address(this), 1e18);

        vm.stopPrank();
    }

    function testRevertDepositIfAmountIsZero() public {
        vm.startPrank(USER);

        vm.expectRevert(bytes("MSCEngine: Invalid amount"));
        mscEngine.depositCollateral(link, 0);

        vm.stopPrank();
    }

    function testDepositCallateral() public {
        vm.startPrank(USER);

        mscEngine.depositCollateral(link, 1e18);
        (uint callateralValue, ) = mscEngine.getUserInfo(USER);
        assertEq(150 * 1e18, callateralValue);

        vm.stopPrank();
    }

    ////////// MINT TESTS //////////

    function testRevertMintIfTokenNotAllowed() public {
        vm.startPrank(USER);

        vm.expectRevert(bytes("MSCEngine: Token not allowed"));
        mscEngine.depositAndMint(address(this), 1e18, 100e18);

        vm.stopPrank();
    }

    function testRevertMintIfAmountIsZero() public {
        vm.startPrank(USER);

        vm.expectRevert(bytes("MSCEngine: Invalid amount"));
        mscEngine.depositAndMint(link, 0, 100e18);

        vm.stopPrank();
    }

    function testMintIsCorrect() public {
        vm.startPrank(USER);

        mscEngine.depositAndMint(link, 1e18, 100e18);
        (, uint debt) = mscEngine.getUserInfo(USER);
        assertEq(100e18, debt);

        vm.stopPrank();
    }

    ////////// REDEEM TESTS //////////

    function testRevertRedeemIfHealthFactorBelowOne() public {
        vm.startPrank(USER);

        mscEngine.depositAndMint(link, 1e18, 100e18);
        vm.expectRevert(bytes("MSCEngine: Health factor below 1"));
        mscEngine.redeemCollateralForMSC(link, 1e18, 25e18);

        vm.stopPrank();
    }

    function testRedeemCollateralForMSC() public {
        vm.startPrank(USER);

        mscEngine.depositAndMint(link, 1e18, 100e18);
        mscEngine.redeemCollateralForMSC(link, 1e9, 50e18);
        (uint callateralValue, uint debt) = mscEngine.getUserInfo(USER);
        assertEq(50 * 1e18, debt);

        vm.stopPrank();
    }

    function testRevertRedeemIfHealthFactorBelowOneBecauseValueDropped() public {
        vm.startPrank(USER);

        mscEngine.depositAndMint(link, 1e18, 100e18);
        MockV3Aggregator(linkPriceFeed).updateAnswer(100e8);
        vm.expectRevert(bytes("MSCEngine: Health factor below 1"));
        mscEngine.redeemCollateralForMSC(link, 1e18, 100e18);

        vm.stopPrank();
    }

    ////////// LIQUIDATION TESTS //////////

    modifier prepareForLiquidation() {
        vm.startPrank(USER);
        mscEngine.depositAndMint(link, 1e18, 100e18);
        vm.stopPrank();

        vm.startPrank(address(mscEngine));
        msc.mint(LIQUIDATOR, 100e18);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        msc.approve(address(mscEngine), 100e18);
        vm.stopPrank();

        _;
    }

    function testLiquidateBurnerHasInsufficientBalance() public prepareForLiquidation {
        // revert if burner has insufficient balance
        vm.startPrank(address(mscEngine));
        msc.transferFrom(LIQUIDATOR, USER, 100e18);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        MockV3Aggregator(linkPriceFeed).updateAnswer(100e8);
        vm.expectRevert(bytes("MSCEngine: Burner has insufficient balance"));
        mscEngine.liquidate(USER, link, 10e18);
        vm.stopPrank();
    }

    function testMustInproveHealhtOnLiquidation() public prepareForLiquidation {
        vm.startPrank(LIQUIDATOR);
        MockV3Aggregator(linkPriceFeed).updateAnswer(100e8);
        vm.expectRevert(bytes("MSCEngine: Health factor still below 1"));
        mscEngine.liquidate(USER, link, 10e18);
        vm.stopPrank();
    }

    function testLiquidationIsCorrect() public prepareForLiquidation {
        vm.startPrank(LIQUIDATOR);
        MockV3Aggregator(linkPriceFeed).updateAnswer(101e8);
        mscEngine.liquidate(USER, link, 98e18);
        (uint callateralValue, uint debt) = mscEngine.getUserInfo(USER);
        assertTrue(debt > 0);
        assertTrue(callateralValue > 0);
        vm.stopPrank();
    }
}
