// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address linkUSDPriceFeed;
        address link;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant LINK_USD_PRICE = 150e8;

    constructor() {
        if (block.chainid == 11_155_111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                linkUSDPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.linkUSDPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator linkUSDPriceFeed = new MockV3Aggregator(DECIMALS, LINK_USD_PRICE);
        ERC20Mock linkMock = new ERC20Mock();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            linkUSDPriceFeed: address(linkUSDPriceFeed), // ETH / USD
            link: address(linkMock)
        });
    }
}
