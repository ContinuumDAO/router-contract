// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract C3GovClient {
    bool _init = false;
    address public gov;
    address public pendingGov;
    mapping(address => bool) public isOperator;
    address[] public operators;

    event ChangeGov(
        address indexed oldGov,
        address indexed newGov,
        uint256 timestamp
    );

    event ApplyGov(
        address indexed oldGov,
        address indexed newGov,
        uint256 timestamp
    );
    modifier onlyGov() {
        require(msg.sender == gov, "C3Gov: only Gov");
        _;
    }

    modifier onlyOperator() {
        require(
            msg.sender == gov || isOperator[msg.sender],
            "C3Gov: only Operator"
        );
        _;
    }

    function initGov(address _gov) internal {
        require(!_init);
        gov = _gov;
        emit ApplyGov(address(0), _gov, block.timestamp);
        _init = true;
    }

    function changeGov(address _gov) external onlyGov {
        pendingGov = _gov;
        emit ChangeGov(gov, _gov, block.timestamp);
    }

    function applyGov() external {
        require(pendingGov != address(0), "C3Gov: empty pendingGov");
        emit ApplyGov(gov, pendingGov, block.timestamp);
        gov = pendingGov;
        pendingGov = address(0);
    }

    function _addOperator(address op) internal {
        require(op != address(0), "C3Caller: Operator is address(0)");
        require(!isOperator[op], "C3Caller: Operator already exists");
        isOperator[op] = true;
        operators.push(op);
    }

    function addOperator(address _op) external onlyGov {
        _addOperator(_op);
    }

    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }

    function revokeOperator(address _op) external onlyGov {
        require(isOperator[_op], "C3Caller: Operator not found");
        isOperator[_op] = false;
        uint256 length = operators.length;
        for (uint256 i = 0; i < length; i++) {
            if (operators[i] == _op) {
                operators[i] = operators[length - 1];
                operators.pop();
                return;
            }
        }
    }
}
