// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "./MPCManageable.sol";

abstract contract MPCAdminControl is MPCManageable {
    address public admin;

    event ChangeAdmin(address indexed _old, address indexed _new);

    constructor(address _admin, address _mpc) MPCManageable(_mpc) {
        admin = _admin;
        emit ChangeAdmin(address(0), _admin);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "MPCAdminControl: not admin");
        _;
    }

    function changeAdmin(address _admin) external onlyMPC {
        emit ChangeAdmin(admin, _admin);
        admin = _admin;
    }
}
