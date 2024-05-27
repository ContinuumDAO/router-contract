// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAI is ERC20 {
    constructor() ERC20("DAI stablecoin", "DAI") {
        //_mint(msg.sender, 1000000 * 10 ** decimals());
    }

    // TEST ONLY
    function print(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() override public pure returns (uint8) {
        return 6;
    }
}