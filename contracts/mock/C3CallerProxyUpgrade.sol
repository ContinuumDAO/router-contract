// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../protocol/IC3Caller.sol";
import "../protocol/C3CallerProxy.sol";

interface IC3CallerProxy2 is IC3CallerProxy {
    function c3callWithVersion(
        uint256 _dappID,
        uint256 _version,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external;
}

contract C3CallerProxyUpgrade is C3CallerProxy, IC3CallerProxy2 {
    mapping(uint256 => address) public c3callerWithVersion;

    function setCallerVersion(
        uint256 version,
        address caller
    ) external onlyOwner {
        c3callerWithVersion[version] = caller;
    }

    function c3callWithVersion(
        uint256 _dappID,
        uint256 _version,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external override onlyAuth {
        IC3Caller(c3callerWithVersion[_version]).c3call(
            _dappID,
            msg.sender,
            _to,
            _toChainID,
            _data
        );
    }
}
