// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployMSC} from "../../script/DeployMSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MSC} from "../../src/MSC.sol";
import {MSCEngine} from "../../src/MSCEngine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployMSC deployMSC;
    MSC msc;
    MSCEngine mscEngine;
    HelperConfig config;
    Handler handler;
    address link;
    address linkPriceFeed;

    function setUp() public {
        deployMSC = new DeployMSC();
        (msc, mscEngine, config) = deployMSC.run();
        (linkPriceFeed, link, ) = config.activeNetworkConfig();

        handler = new Handler(msc, mscEngine);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreCollateralThanDebt() public view {
        // only way to mint debt(msc) is to deposit collateral
        uint totalDept = msc.totalSupply();
        uint totalCollateral = IERC20(link).balanceOf(address(mscEngine));
        uint totalCollateralValue = mscEngine.getUSDValue(link, totalCollateral);

        console.log("Total Debt: ", totalDept);
        console.log("Total Collateral: ", totalCollateral);

        assertTrue(totalCollateralValue >= (totalDept * 3) / 2);
    }
}
