// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IC3Caller.sol";

abstract contract C3CallerDapp is IC3Dapp {
    address public c3CallerProxy;

    modifier onlyExecutor() {
        require(
            IC3CallerProxy(c3CallerProxy).isExecutor(msg.sender),
            "C3CallerDapp: onlyExecutor"
        );
        _;
    }

    modifier onlyCaller() {
        require(
            IC3CallerProxy(c3CallerProxy).isCaller(msg.sender),
            "C3CallerDapp: onlyCaller"
        );
        _;
    }

    constructor(address _c3CallerProxy) {
        c3CallerProxy = _c3CallerProxy;
    }

    function _c3Fallback(
        uint256 dappID,
        bytes32 swapID,
        bytes calldata data,
        bytes calldata reason
    ) internal virtual;

    function c3Fallback(
        uint256 dappID,
        bytes32 swapID,
        bytes calldata data,
        bytes calldata reason
    ) external override onlyExecutor {
        return _c3Fallback(dappID, swapID, data, reason);
    }

    function context()
        internal
        view
        returns (
            bytes32 swapID,
            string memory fromChainID,
            string memory sourceTx
        )
    {
        return IC3Caller(c3CallerProxy).context();
    }
}
