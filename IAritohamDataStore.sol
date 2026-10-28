// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AritohamTypes.sol";

interface IAritohamDataStore {
    function getUser(address) external view returns (User memory);
    function getIncome(address) external view returns (Income memory);
    function getFlow(address) external view returns (Flow memory);
    function getRankCfg(uint256) external view returns (RankCfg memory);
    function getDaoCycle(uint256) external view returns (DaoCycle memory);
    function getDirects(address) external view returns (address[] memory);
    function idToUser(uint32) external view returns (address);
    function counts(address) external view returns (uint256[11] memory);
    function weeklyMatching(address) external view returns (uint256);
    function dailyMatching(address) external view returns (uint256);
    function dayDirectBusiness(address, uint256) external view returns (uint128);
    function dayNewDirects(address, uint256) external view returns (uint32);
    function dayIncome(address, uint256) external view returns (uint128);

    function stakes(address, uint256) external view returns (uint40, uint128, uint128, uint128, uint32);
    function purchases(address, uint256) external view returns (uint40, uint40, uint128, uint128, uint128);
    function directRecs(address, uint256) external view returns (uint40, address, uint128, uint128);
    function genRecs(address, uint256) external view returns (uint40, address, uint8, uint128, uint128);
    function roiRecs(address, uint256) external view returns (uint40, uint32, uint32, uint128, uint128);
    function rankRewardRecs(address, uint256) external view returns (uint40, uint8, uint64, uint128);
    function rankIncentiveRecs(address, uint256) external view returns (uint40, uint8, uint64, uint128);
    function sells(address, uint256) external view returns (uint40, uint128, uint128, uint128);
    function withdraws(address, uint256) external view returns (uint40, uint128, uint128, uint128, uint128);
    function userDaoPayouts(address, uint256) external view returns (uint32, uint32);
    function cyclePayouts(uint256, uint256) external view returns (address, uint40, uint32, uint128, uint128, uint32);
    function eligibleWallets(uint256, uint256) external view returns (address);
    function eligibleLength(uint256) external view returns (uint256);
    function cyclePayoutsLength(uint256) external view returns (uint256);
    function cycleDeposit(uint256) external view returns (uint256);
    function currentCycle() external view returns (uint256);
    function lifetimeHolders() external view returns (uint256);
    function totalUsers() external view returns (uint256);

    function pricePoints(uint256) external view returns (uint40, uint128);
    function pricePointsLength() external view returns (uint256);
    function latestPrice() external view returns (uint128);
    function dailyLimit() external view returns (uint256);
    function daoBps() external view returns (uint256);
    function dailyRewardPpm() external view returns (uint256);
    function activeDirectMin() external view returns (uint256);
}
