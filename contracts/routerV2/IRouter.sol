// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IRouter {
    event LogSwapIn(
        address indexed token,
        address indexed to,
        bytes32 indexed swapoutID,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        string sourceTx
    );

    event LogSwapInPending(
        address indexed token,
        address indexed to,
        bytes32 indexed swapoutID,
        uint256 amount,
        uint256 feeRate
    );

    event LogSwapOut(
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
    event LogAnySwapInAndExec(
        address indexed dapp,
        address indexed receiver,
        bytes32 swapID,
        address token,
        uint256 amount,
        uint256 fromChainID,
        string sourceTx,
        bool success,
        bytes result
    );

    event LogSwapFallback(
        bytes32 indexed swapID,
        address indexed token,
        address indexed receiver,
        uint256 amount,
        bytes reason
    );
}
