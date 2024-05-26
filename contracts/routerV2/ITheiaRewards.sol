// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

interface ITheiaRewards {
    function calculateRewards(uint256 tokenId) external returns(uint256);
    function unclaimedRewards(uint256 tokenId) external returns(uint256);
    function updateRewards(uint256 tokenId, uint256 rewards, address owner) external;
    function getFeeToken() external view returns(address);
    function getRewardToken() external view returns(address);
    function claimBaseRewards(uint256 tokenId) external returns(uint256);
}