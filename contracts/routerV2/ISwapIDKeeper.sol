// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISwapIDKeeper {
    function registerSwapin(bytes32 swapID) external;

    function registerSwapoutEvm(
        address token,
        address from,
        uint256 amount,
        address receiver,
        uint256 toChainID
    ) external returns (bytes32 swapID);

    function registerSwapoutNonEvm(
        address token,
        address from,
        uint256 amount,
        string calldata receiver,
        string calldata toChainID
    ) external returns (bytes32 swapID);

    function isSwapCompleted(bytes32 swapID) external view returns (bool);
}
