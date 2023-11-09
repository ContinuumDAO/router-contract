// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISwapIDKeeper {
    function registerSwapin(bytes32 swapID) external;

    function registerSwapout(
        uint256 dappID,
        address token,
        address from,
        string calldata to,
        uint256 amount,
        string calldata toChainID,
        bytes calldata data
    ) external returns (bytes32 swapID);

    function genSwapID(
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) external returns (bytes32 swapID);

    function isSwapCompleted(bytes32 swapID) external view returns (bool);
}
