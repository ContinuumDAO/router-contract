// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "./CtmDaoV1Router.sol";

contract DeployRouterV1 {
    address public owner;

    mapping(string => address) public routers;

    constructor() {
        owner = msg.sender;
    }

    event NewRouter(address indexed addr);

    function newRouter(
        address _wNATIVE,
        address _mpc,
        string memory _name
    ) external returns (address) {
        require(owner == msg.sender, "DeployRouterV1: no permission");
        if (routers[_name] != address(0)) {
            return routers[_name];
        }
        bytes32 salt = keccak256(abi.encodePacked(_wNATIVE, _mpc, _name));
        CtmDaoV1Router cr = new CtmDaoV1Router{salt: salt}(_wNATIVE, _mpc);
        routers[_name] = address(cr);
        emit NewRouter(address(cr));
        return address(cr);
    }
}
