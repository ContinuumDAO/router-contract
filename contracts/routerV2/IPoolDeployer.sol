// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

interface IPoolDeployer {
    function getSymbolByToken(string memory tokenStr, string memory toChainIdStr) external view returns(string memory tokenSymbol);
    function getTokenBySymbol(string memory tokenSymbol, string memory toChainIdStr) external view returns(string memory tokenStr);
}