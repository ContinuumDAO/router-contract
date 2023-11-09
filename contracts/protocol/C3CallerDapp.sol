// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IC3Caller.sol";

abstract contract C3CallerDapp is IC3Dapp {
    address public c3CallerProxy;

    modifier onlyExecutor() {
        require(IC3CallerProxy(c3CallerProxy).isExecutor(msg.sender));
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
}
