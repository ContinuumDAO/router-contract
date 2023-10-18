// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IC3Executor {
    function context()
        external
        view
        returns (
            address user,
            uint256 fromChainID,
            bytes32 swapID,
            string memory sourceTx
        );

    function execute(
        bytes32 _swapID,
        address _dapp,
        address _from,
        uint256 _fromChainID,
        string calldata _sourceTx,
        bytes calldata _data
    ) external returns (bool success, bytes memory result);
}
