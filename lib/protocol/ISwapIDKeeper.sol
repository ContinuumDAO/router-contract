// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISwapIDKeeper {
    function registerSwapin(bytes32 uuid) external;

    function registerSwapout(
        uint256 dappID,
        address token,
        address from,
        string calldata to,
        uint256 amount,
        string calldata toChainID,
        bytes calldata data
    ) external returns (bytes32 uuid);

    function genUUID(
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) external returns (bytes32 uuid);

    function isSwapCompleted(bytes32 uuid) external view returns (bool);
}
