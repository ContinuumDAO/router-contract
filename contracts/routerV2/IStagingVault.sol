// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

struct RewardedToken {
    string symbol;
    uint256 standardRewardRate;
    string[] tokensStr;
    string[] toChainIdsStr;
    uint256[] rateFactors;
}

interface IStagingVault {
    function changeTheiaGov(address newGovTHEIA) external returns(bool);
    function setUp(address ve, address theiaRewards, address feeToken) external;
    function isRewardedToken(string memory tokenSymbol) external view returns(bool);
    function depositStaging(string memory tokenStr, uint256 amount) external returns(uint256);
    function withdrawStaging(string memory tokenStr, uint256 amount, address receiver) external returns(uint256);
    //function addRewardToken(address token, uint256 rewardRate) external returns(bool);
    function addRewardToken(
        string memory tokenSymbol,
        string memory tokenStr,
        uint256 standardRewardRate,
        string memory toChainIdStr,
        uint256 rateFactor,
        string memory targetStr
    ) external;
    function getRewardRate(string memory tokenSymbol, string memory chainIdStr, uint256 _timestamp) external view returns(uint256);
    function getRewardRate(string memory tokenSymbol, string memory chainIdStr) external view returns(uint256);
    function attachLiquidity(
        uint256 tokenId,
        string memory targetStr,
        string memory tokenSymbol,
        string memory toChainIdStr,
        uint256 amount,
        uint256 fee
    ) external returns(uint256);
    function detachLiquidity(
        uint256 tokenId,
        string memory tokenSymbol,
        string memory targetStr,
        string memory toChainIdStr,
        uint256 amount,
        uint256 swapFee
    ) external returns(uint256);
    function getCompletedStatus(uint256 nonce) external view returns(bool);
    function getRewardToken(string memory tokenSymbol) external view returns(RewardedToken memory);
    function getRewardRateEnd(string memory tokenSymbol, string memory chainIdStr) external view returns(uint256);
    function getLiquidityRemovalTime(
        uint256 tokenId, 
        string memory tokenSymbol, 
        string memory chainIdStr
    ) external view returns(uint256);
    function getStakedTokenSymbols() external view returns(string[] memory);
    function tokenSymbolExists(string memory tokenSymbol) external view returns(bool, bool);
    function getTokenStakedAllChains(string memory tokenSymbol) external view returns(uint256);
    function getTokenStakedByChain(
        string memory tokenSymbol, 
        string memory chainIdStr
    ) external view returns(uint256);
    function getTokenStakedByTokenId(
        uint256 tokenId, 
        string memory tokenSymbol
    ) external view returns(uint256);
    function getTokenStakedByTokenIdAndChain(
        uint256 tokenId, 
        string memory tokenSymbol, 
        string memory chainIdStr
    ) external view returns(uint256);
    function getStakedAllChains(uint256 tokenId) external view 
        returns(string[] memory, uint256[] memory, bool);
    function getLiquidityOfAt(
        uint256 _tokenId, 
        string memory _tokenSymbol, 
        string memory _chainIdStr,
        uint256 _timestamp
    ) external view returns(uint256);
    function getRewardRateOfAt(
        string memory _tokenSymbol, 
        string memory _chainIdStr,
        uint256 _timestamp
    ) external view returns(uint256);
    function getLiquidity(address token) external view returns(uint256,uint256);
    function getStandardRewardRate(string memory tokenSymbol, uint256 _timestamp) external view returns(uint256);
    function getStandardRewardRate(string memory tokenSymbol) external view returns(uint256);

}