// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IRouter {
    event LogTheiaVault(
        address indexed token,
        address indexed to,
        bytes32 indexed swapoutID,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        string sourceTx
    );

    event LogTheiaCross(
        address indexed token,
        address indexed from,
        bytes32 indexed swapoutID,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 fee,
        address feeToken,
        string receiver
    );

    event LogTheiaFallback(
        bytes32 indexed swapID,
        address indexed token,
        address indexed receiver,
        uint256 amount,
        bytes reason
    );
}
