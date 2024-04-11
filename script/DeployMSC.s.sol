// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MSC} from "../src/MSC.sol";
import {MSCEngine} from "../src/MSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMSC is Script {
    function run() external returns (MSC, MSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address linkPriceFeed, address link) = config.activeNetworkConfig();

        vm.startBroadcast();
        MSC msc = new MSC();

        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = link;
        address[] memory priceFeeds = new address[](1);
        priceFeeds[0] = linkPriceFeed;

        MSCEngine mscEngine = new MSCEngine(tokenAddresses, priceFeeds, address(msc));
        msc.transferOwnership(address(mscEngine));
        vm.stopBroadcast();

        return (msc, mscEngine, config);
    }
}
