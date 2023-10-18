// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

import "../routerV1/IC3DApp.sol";
import "../routerV1/IC3Executor.sol";

contract DAppDemo is IC3DApp {
    event LogC3Execute(
        address user,
        uint256 fromChainID,
        bytes32 swapID,
        string sourceTx,
        bytes data
    );

    constructor() {}

    function c3call(
        string calldata message,
        address receiver,
        uint256 toChainId
    ) external payable {}

    function c3Execute(
        bytes calldata data
    ) external override returns (bool success, bytes memory result) {
        (
            address user,
            uint256 fromChainID,
            bytes32 swapID,
            string memory sourceTx
        ) = IC3Executor(msg.sender).context();
        emit LogC3Execute(user, fromChainID, swapID, sourceTx, data);
        return (true, "");
    }
}
