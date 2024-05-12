// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISwapIDKeeper {
    struct SwapEvmData {
        address token;
        address from;
        uint256 amount;
        address receiver;
        uint256 toChainID;
    }

    struct SwapNonEvmData {
        address token;
        address from;
        uint256 amount;
        string receiver;
        string toChainID;
    }

    function registerSwapin(bytes32 swapID) external;

    function isSwapoutIDExist(bytes32 swapoutID) external view returns (bool);

    function registerSwapoutEvm(
        SwapEvmData memory data
    ) external returns (bytes32 swapID);

    function registerSwapoutNonEvm(
        SwapNonEvmData memory data
    ) external returns (bytes32 swapID);

    function isSwapCompleted(bytes32 swapID) external view returns (bool);
}
