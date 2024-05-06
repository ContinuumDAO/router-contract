// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../protocol/C3CallerDapp.sol";

abstract contract GovernDapp is C3CallerDapp {
    // delay for timelock functions
    uint public delay = 2 days;

    address private _oldGov;
    address private _newGov;
    uint256 private _newGovEffectiveTime;

    constructor(
        address _gov,
        address _c3callerProxy,
        uint256 _dappID
    ) C3CallerDapp(_c3callerProxy, _dappID) {
        _oldGov = _gov;
        _newGov = _gov;
        _newGovEffectiveTime = block.timestamp;
    }

    event LogChangeGov(
        address indexed oldGov,
        address indexed newGov,
        uint indexed effectiveTime,
        uint256 chainID
    );

    modifier onlyGov() {
        require(msg.sender == gov() || isCaller(msg.sender), "Gov FORBIDDEN");
        _;
    }

    function gov() public view returns (address) {
        if (block.timestamp >= _newGovEffectiveTime) {
            return _newGov;
        }
        return _oldGov;
    }

    function changeGov(address newGov) external onlyGov {
        require(newGov != address(0), "newGov is empty");
        _oldGov = gov();
        _newGov = newGov;
        _newGovEffectiveTime = block.timestamp + delay;
        emit LogChangeGov(
            _oldGov,
            _newGov,
            _newGovEffectiveTime,
            block.chainid
        );
    }

    function setDelay(uint _delay) external onlyGov {
        delay = _delay;
    }
}
