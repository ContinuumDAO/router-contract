// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IC3Caller.sol";
import "./ISwapIDKeeper.sol";

contract C3Caller is IC3Caller {
    struct Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
    }

    Context public override context;

    address public mpc;
    address public pendingMPC;

    mapping(address => bool) public isOperator;
    address[] public operators;

    address public swapIDKeeper;

    /// @dev Access control function
    modifier onlyMPC() {
        require(msg.sender == mpc, "C3Caller: only MPC");
        _;
    }

    modifier onlyAuth() {
        require(isOperator[msg.sender], "C3Caller: AUTH FORBIDDEN");
        _;
    }

    event ChangeMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint256 timestamp
    );
    event ApplyMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint256 timestamp
    );
    event LogCall(
        bytes32 indexed swapoutID,
        address indexed to,
        string fromChainID,
        string sourceTx,
        bytes data
    );

    constructor(address _mpc, address _swapIDKeeper) {
        require(_mpc != address(0));
        mpc = _mpc;
        swapIDKeeper = _swapIDKeeper;
        _addOperator(_mpc);
        emit ApplyMPC(address(0), _mpc, block.timestamp);
    }

    receive() external payable {}

    fallback() external payable {}

    function changeMPC(address _mpc) external onlyMPC {
        pendingMPC = _mpc;
        emit ChangeMPC(mpc, _mpc, block.timestamp);
    }

    function applyMPC() external {
        require(msg.sender == pendingMPC);
        emit ApplyMPC(mpc, pendingMPC, block.timestamp);
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

    function execute(
        bytes32 _swapID,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        bytes calldata _data
    ) external virtual override onlyAuth {
        require(_data.length > 0, "C3Caller: empty calldata");
        ISwapIDKeeper(swapIDKeeper).registerSwapin(_swapID);

        context = Context({
            swapID: _swapID,
            fromChainID: _fromChainID,
            sourceTx: _sourceTx
        });

        bool success;
        string memory result;

        try IC3CallExecutor(_to).call(_swapID, _data) returns (
            bool succ,
            bytes memory res
        ) {
            (success, result) = (succ, string(res));
        } catch Error(string memory reason) {
            result = reason;
        } catch (bytes memory reason) {
            result = string(reason);
        }

        context = Context({swapID: "", fromChainID: "", sourceTx: ""});

        emit LogCall(_swapID, _to, _fromChainID, _sourceTx, _data);
    }
}