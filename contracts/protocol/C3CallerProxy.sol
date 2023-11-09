// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IC3Caller.sol";

contract C3CallerProxy is IC3Caller, IC3CallerProxy {
    address public mpc;
    address public pendingMPC;

    address public c3caller;

    mapping(address => bool) public isOperator;
    address[] public operators;

    /// @dev Access control function
    modifier onlyMPC() {
        require(msg.sender == mpc, "C3CallerProxy: only MPC");
        _;
    }

    modifier onlyAuth() {
        require(isOperator[msg.sender], "C3CallerProxy: AUTH FORBIDDEN");
        _;
    }

    constructor(address _mpc, address _c3caller) {
        require(_mpc != address(0));
        mpc = _mpc;
        _addOperator(_mpc);
        c3caller = _c3caller;
    }

    function changeMPC(address _mpc) external onlyMPC {
        pendingMPC = _mpc;
    }

    function applyMPC() external {
        require(msg.sender == pendingMPC);
        mpc = pendingMPC;
        pendingMPC = address(0);
    }

    function _addOperator(address op) internal {
        require(op != address(0), "C3Caller: Operator is address(0)");
        require(!isOperator[op], "C3Caller: Operator already exists");
        isOperator[op] = true;
        operators.push(op);
    }

    function addOperator(address _auth) external onlyMPC {
        _addOperator(_auth);
    }

    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }

    function revokeOperator(address _auth) external onlyMPC {
        require(isOperator[_auth], "C3Caller: Operator not found");
        isOperator[_auth] = false;
        uint256 length = operators.length;
        for (uint256 i = 0; i < length; i++) {
            if (operators[i] == _auth) {
                operators[i] = operators[length - 1];
                operators.pop();
                return;
            }
        }
    }

    function isExecutor(address sender) external view override returns (bool) {
        return isOperator[sender];
    }

    function context()
        external
        view
        override
        returns (
            bytes32 swapID,
            string memory fromChainID,
            string memory sourceTx
        )
    {
        return IC3Caller(c3caller).context();
    }

    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external override {
        IC3Caller(c3caller).c3call(_dappID, _to, _toChainID, _data);
    }

    function execute(
        uint256 _dappID,
        bytes32 _swapID,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        string calldata _fallback,
        bytes calldata _data
    ) external virtual override onlyAuth {
        IC3Caller(c3caller).execute(
            _dappID,
            _swapID,
            _to,
            _fromChainID,
            _sourceTx,
            _fallback,
            _data
        );
    }
}
