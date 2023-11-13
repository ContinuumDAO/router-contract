// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IC3CallerProxy {
    function isExecutor(address sender) external returns (bool);

    function isCaller(address sender) external returns (bool);
}

interface IC3Dapp {
    function c3Fallback(
        uint256 dappID,
        bytes32 swapID,
        bytes calldata data,
        bytes calldata reason
    ) external;
}

interface IC3Caller {
    function context()
        external
        view
        returns (
            bytes32 swapID,
            string memory fromChainID,
            string memory sourceTx
        );

    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external;

    function execute(
        uint256 _dappID,
        bytes32 _swapID,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        string calldata _fallback,
        bytes calldata _data
    ) external;
}

interface IC3CallExecutor {
    function execCall(
        bytes32 _swapID,
        bytes calldata _data
    ) external returns (bool success, bytes memory result);
}
