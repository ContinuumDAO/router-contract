// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../routerV2/TheiaERC20.sol";

contract TestTheiaERC20 is IERC20, TheiaERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _underlying,
        address _admin
    ) TheiaERC20(_name, _symbol, _decimals, _underlying, _admin) {}

    // for test
    function setDelay(uint t) external {
        DELAY = t;
    }
}
