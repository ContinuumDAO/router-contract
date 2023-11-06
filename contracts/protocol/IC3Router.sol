// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IC3Router {
    function context()
        external
        view
        returns (
            bytes32 swapID,
            string memory fromChainID,
            string memory sourceTx
        );

    function swapOut(
        uint256 dappID,
        address token,
        uint256 amount,
        string calldata toChainID,
        string calldata to,
        string calldata receiver
    ) external returns (bytes32);

    function swapOutNative(
        uint256 dappID,
        string calldata toChainID,
        string calldata to,
        string calldata receiver
    ) external payable returns (bytes32);

    function swapOutAndCall(
        uint256 dappID,
        address token,
        uint256 amount,
        string calldata toChainID,
        string calldata to,
        string calldata receiver,
        bytes calldata data
    ) external returns (bytes32);

    function swapOutNativeAndCall(
        uint256 dappID,
        string calldata toChainID,
        string calldata to,
        string calldata receiver,
        bytes calldata data
    ) external payable returns (bytes32);
}

interface IC3RouterExecutor {
    function execute(
        bytes32 _swapID,
        address _token,
        address _to,
        uint256 _amouunt
    ) external returns (bool success, bytes memory result);

    function executeAndCall(
        bytes32 _swapID,
        address _token,
        address _to,
        uint256 _amouunt,
        bytes calldata _data
    ) external returns (bool success, bytes memory result);
}
