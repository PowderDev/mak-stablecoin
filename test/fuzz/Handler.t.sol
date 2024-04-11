// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MSC} from "../../src/MSC.sol";
import {MSCEngine} from "../../src/MSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    MSC msc;
    MSCEngine mscEngine;

    address link;

    address public LIQUIDATOR = makeAddr("liquidator");
    uint public DEFAULT_BALANCE = 1000e18;

    constructor(MSC _msc, MSCEngine _mscEngine) {
        msc = _msc;
        mscEngine = _mscEngine;

        address[] memory collateralAddressses = mscEngine.getCollateralAddresses();
        link = collateralAddressses[0];
    }

    modifier mintCollateralToSender(address collateralAddress) {
        vm.startPrank(msg.sender);
        ERC20Mock(collateralAddress).mint(msg.sender, DEFAULT_BALANCE);
        ERC20Mock(collateralAddress).approve(address(mscEngine), DEFAULT_BALANCE);
        msc.approve(address(mscEngine), DEFAULT_BALANCE);
        vm.stopPrank();

        _;
    }

    function depositCollateral(uint amount) public mintCollateralToSender(link) {
        vm.startPrank(msg.sender);
        amount = bound(amount, 1, DEFAULT_BALANCE);
        mscEngine.depositCollateral(link, amount);
        vm.stopPrank();
    }

    function redeemCollateral(uint amount) public mintCollateralToSender(link) {
        vm.startPrank(msg.sender);
        (uint existingCollateral, uint existingDebt) = mscEngine.getUserInfo(msg.sender);
        if (existingCollateral > 0 || existingDebt > 0) return;
        mscEngine.depositCollateral(link, DEFAULT_BALANCE);
        amount = bound(amount, 1, DEFAULT_BALANCE);
        mscEngine.redeemCollateral(link, amount);
        vm.stopPrank();
    }

    function depositAndmint(uint collateralAmount) public mintCollateralToSender(link) {
        vm.startPrank(msg.sender);
        vm.assume(msg.sender != address(0));
        collateralAmount = bound(collateralAmount, 1, DEFAULT_BALANCE);
        uint collateralAmountValue = mscEngine.getUSDValue(link, collateralAmount);
        uint mintAmount = (collateralAmountValue * 2) / 3;
        mscEngine.depositAndMint(link, collateralAmount, mintAmount);
        vm.stopPrank();
    }
}
