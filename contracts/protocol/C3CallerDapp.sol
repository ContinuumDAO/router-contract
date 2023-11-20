// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IC3Caller.sol";

abstract contract C3CallerDapp is IC3Dapp {
    address public c3CallerProxy;
    uint256 public dappID;

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

    constructor(address _c3CallerProxy, uint256 _dappID) {
        c3CallerProxy = _c3CallerProxy;
        dappID = _dappID;
    }

    function _c3Fallback(
        uint256 dappID,
        bytes32 swapID,
        bytes calldata data,
        bytes calldata reason
    ) internal virtual returns (bool);

    function c3Fallback(
        uint256 _dappID,
        bytes32 _swapID,
        bytes calldata _data,
        bytes calldata _reason
    ) external override onlyExecutor returns (bool) {
        require(_dappID == dappID, "dappID dismatch");
        return _c3Fallback(_dappID, _swapID, _data, _reason);
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
        return IC3CallerProxy(c3CallerProxy).context();
    }

    function c3call(
        string memory _to,
        string memory _toChainID,
        bytes memory _data
    ) internal {
        IC3CallerProxy(c3CallerProxy).c3call(dappID, _to, _toChainID, _data);
    }
}
