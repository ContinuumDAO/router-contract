// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IC3Caller {
    function context()
        external
        view
        returns (
            bytes32 swapID,
            string memory fromChainID,
            string memory sourceTx
        );

    function execute(
        bytes32 _swapID,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        bytes calldata _data
    ) external;
}

interface IC3CallExecutor {
    function context()
        external
        view
        returns (
            address user,
            uint256 fromChainID,
            bytes32 swapID,
            string memory sourceTx
        );

    function call(
        bytes32 _swapID,
        bytes calldata _data
    ) external returns (bool success, bytes memory result);
}
