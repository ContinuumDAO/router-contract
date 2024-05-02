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

    // TODO need add feeToken
    event LogSwapOut(
        address indexed token,
        address indexed from,
        string to,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 fee,
        bytes32 swapoutID,
        bytes data
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
        bytes4 selector,
        bytes data,
        bytes reason
    );

    struct PendingCross {
        address token;
        address to;
        uint256 amount;
        uint256 tokenDecimals;
        address fromTokenAddr;
        uint256 fromChainID;
        string sourceTx;
    }
}
