// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "./CtmDaoV1ERC20.sol";

contract DeployTokenFactoryV1 {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    event NewToken(address indexed addr);

    function newToken(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _underlying,
        address _vault
    ) external returns (address) {
        require(owner == msg.sender, "DeployTokenFactoryV1: no permission");
        bytes32 salt = keccak256(
            abi.encodePacked(_name, _symbol, _decimals, _underlying, _vault)
        );
        CtmDaoV1ERC20 t = new CtmDaoV1ERC20{salt: salt}(
            _name,
            _symbol,
            _decimals,
            _underlying,
            _vault
        );
        emit NewToken(address(t));
        return address(t);
    }
}
