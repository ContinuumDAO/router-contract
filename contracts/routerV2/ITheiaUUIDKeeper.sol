// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITheiaUUIDKeeper {
    struct EvmData {
        address token;
        address from;
        uint256 amount;
        address receiver;
        uint256 toChainID;
    }

    struct NonEvmData {
        address token;
        address from;
        uint256 amount;
        string receiver;
        string toChainID;
    }

    function registerUUID(bytes32 uuid) external;

    function isExist(bytes32 uuid) external view returns (bool);

    function genUUIDEvm(EvmData memory data) external returns (bytes32 uuid);

    function genUUIDNonEvm(
        NonEvmData memory data
    ) external returns (bytes32 uuid);

    function isCompleted(bytes32 uuid) external view returns (bool);
}
