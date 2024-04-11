// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MSC.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MSCEngine {
    event CollateralDeposited(address indexed depositor, address indexed token, uint amount);
    event CollateralRedeemed(address indexed redeemer, address indexed token, uint amount);
    event DebtMinted(address indexed to, uint amount);
    event DebtBurned(address indexed from, uint amount);
    event Liquidated(address indexed user, address indexed collateralAddress, uint amount);

    uint private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint private constant PRECISION = 1e18;

    mapping(address token => address priceFeed) private tokenToPriceFeed;
    mapping(address user => mapping(address token => uint amount)) private collateralBalances;
    mapping(address => uint) private debtBalances;
    address[] private collateralAddresses;

    MSC private immutable i_msc;

    constructor(address[] memory tokenAddresses, address[] memory priceFeeds, address mscAddress) {
        require(tokenAddresses.length == priceFeeds.length, "MSCEngine: Invalid input");

        for (uint i = 0; i < tokenAddresses.length; i++) {
            tokenToPriceFeed[tokenAddresses[i]] = priceFeeds[i];
            collateralAddresses.push(tokenAddresses[i]);
        }

        i_msc = MSC(mscAddress);
    }

    modifier isAllowedCollateral(address token) {
        require(tokenToPriceFeed[token] != address(0), "MSCEngine: Token not allowed");
        _;
    }

    modifier isAmountZero(uint amount) {
        require(amount != 0, "MSCEngine: Invalid amount");
        _;
    }

    function depositAndMint(
        address collateralAddress,
        uint amount,
        uint mintAmount
    ) external isAllowedCollateral(collateralAddress) isAmountZero(amount) {
        depositCollateral(collateralAddress, amount);
        mint(msg.sender, mintAmount);
    }

    function depositCollateral(
        address collateralAddress,
        uint amount
    ) public isAllowedCollateral(collateralAddress) isAmountZero(amount) {
        collateralBalances[msg.sender][collateralAddress] += amount;

        ERC20(collateralAddress).transferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, collateralAddress, amount);
    }

    function mint(address to, uint amount) public isAmountZero(amount) {
        require(to != address(0), "MSCEngine: Invalid address");

        i_msc.mint(to, amount);
        debtBalances[to] += amount;

        require(_healthFactor(to) >= 1, "MSCEngine: Health factor below 1");
        emit DebtMinted(to, amount);
    }

    function redeemCollateralForMSC(
        address collateralAddress,
        uint amount,
        uint burnAmount
    ) external isAllowedCollateral(collateralAddress) isAmountZero(amount) {
        require(_healthFactor(msg.sender) >= 1, "MSCEngine: Health factor below 1");

        burn(burnAmount);
        redeemCollateral(collateralAddress, amount);
    }

    function redeemCollateral(
        address collateralAddress,
        uint amount
    ) public isAllowedCollateral(collateralAddress) isAmountZero(amount) {
        _redeemCollateral(collateralAddress, amount, msg.sender, msg.sender);
        require(_healthFactor(msg.sender) >= 1, "MSCEngine: Health factor below 1");
    }

    function burn(uint amount) public isAmountZero(amount) {
        _burn(msg.sender, amount, msg.sender);
    }

    function liquidate(address user, address collateralAddress, uint debtToCover) public {
        require(_healthFactor(user) < 1, "MSCEngine: Health factor above 1");

        uint tokenAmountForCoveredDebt = getTokenAmountForUSD(collateralAddress, debtToCover);
        uint amountToRedeem = tokenAmountForCoveredDebt >
            collateralBalances[user][collateralAddress]
            ? collateralBalances[user][collateralAddress]
            : tokenAmountForCoveredDebt;

        _burn(user, debtToCover, msg.sender);
        _redeemCollateral(collateralAddress, amountToRedeem, user, msg.sender);

        require(_healthFactor(user) >= 1, "MSCEngine: Health factor still below 1");

        emit Liquidated(user, collateralAddress, amountToRedeem);
    }

    function getUserInfo(address user) public view returns (uint collateralValue, uint debtValue) {
        collateralValue = getAccountCollateral(user);
        debtValue = debtBalances[user];
    }

    function getAccountCollateral(address user) public view returns (uint totalValue) {
        for (uint i = 0; i < collateralAddresses.length; i++) {
            address token = collateralAddresses[i];
            totalValue += getUSDValue(token, collateralBalances[user][token]);
        }
    }

    function getUSDValue(address token, uint amount) public view returns (uint) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenToPriceFeed[token]);
        (, int price, , , ) = priceFeed.latestRoundData();
        return (uint(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getTokenAmountForUSD(address token, uint usdAmount) public view returns (uint) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenToPriceFeed[token]);
        (, int price, , , ) = priceFeed.latestRoundData();
        return (usdAmount * PRECISION) / (uint(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getCollateralAddresses() public view returns (address[] memory) {
        return collateralAddresses;
    }

    function getUserCollateral(address user, address token) public view returns (uint) {
        return collateralBalances[user][token];
    }

    function _healthFactor(address user) internal view returns (uint) {
        (uint collateralValue, uint debtValue) = getUserInfo(user);

        if (debtValue == 0) {
            return 1;
        }

        return collateralValue / ((debtValue * 3) / 2);
    }

    function _redeemCollateral(
        address collateralAddress,
        uint amount,
        address from,
        address to
    ) internal {
        require(
            collateralBalances[from][collateralAddress] >= amount,
            "MSCEngine: Insufficient collateral balance"
        );

        collateralBalances[from][collateralAddress] -= amount;

        ERC20(collateralAddress).transfer(to, amount);

        emit CollateralRedeemed(from, collateralAddress, amount);
    }

    function _burn(address onBehafeOf, uint amount, address burnFrom) internal {
        require(debtBalances[onBehafeOf] >= amount, "MSCEngine: Insufficient debt balance");

        if (onBehafeOf != burnFrom) {
            require(
                ERC20(i_msc).balanceOf(burnFrom) >= amount,
                "MSCEngine: Burner has insufficient balance"
            );
        }

        ERC20(i_msc).transferFrom(burnFrom, address(this), amount);
        i_msc.burn(amount);
        debtBalances[onBehafeOf] -= amount;

        emit DebtBurned(burnFrom, amount);
    }
}
