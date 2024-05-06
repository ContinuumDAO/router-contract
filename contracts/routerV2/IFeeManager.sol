// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IFeeManager {
    function getGasFee(
        uint256 fromChainID,
        uint256 toChainID,
        address feeToken
    ) external returns (uint256);

    function getLiquidityFeeFactor(
        uint256 liquidity,
        uint256 amount
    ) external returns (uint256);

    function getBaseLiquidityFee(address feeToken) external returns (uint256);
}
