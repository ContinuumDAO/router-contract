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

    event LogC3Call(
        uint256 indexed dappID,
        bytes32 indexed swapoutID,
        address caller,
        string toChainID,
        string to,
        bytes data
    );

    event LogFallbackCall(
        uint256 indexed dappID,
        bytes32 indexed swapoutID,
        string indexed to,
        bytes data,
        bytes reason
    );

    event LogExecCall(
        uint256 indexed dappID,
        address indexed to,
        bool indexed success,
        bytes32 swapoutID,
        string fromChainID,
        string sourceTx,
        bytes data,
        bytes reasons
    );

    event LogExecFallback(
        uint256 indexed dappID,
        address indexed to,
        bool indexed success,
        bytes32 swapoutID,
        string fromChainID,
        string sourceTx,
        bytes fallbackReason,
        bytes data,
        bytes reasons
    );

    constructor(address _mpc, address _swapIDKeeper) {
        require(_mpc != address(0));
        mpc = _mpc;
        swapIDKeeper = _swapIDKeeper;
        _addOperator(_mpc);
        emit ApplyMPC(address(0), _mpc, block.timestamp);
    }

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

    function c3call(
        uint256 _dappID,
        address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external override {
        require(_dappID > 0, "C3Caller: empty dappID");
        require(bytes(_to).length > 0, "C3Caller: empty _to");
        require(bytes(_toChainID).length > 0, "C3Caller: empty toChainID");
        require(_data.length > 0, "C3Caller: empty calldata");
        bytes32 _swapID = ISwapIDKeeper(swapIDKeeper).genUUID(
            _dappID,
            _to,
            _toChainID,
            _data
        );
        emit LogC3Call(_dappID, _swapID, _caller, _toChainID, _to, _data);
    }

    function execute(
        uint256 _dappID,
        bytes32 _swapID,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        string calldata _fallback,
        bytes calldata _data
    ) external override onlyAuth {
        require(_data.length > 0, "C3Caller: empty calldata");
        require(
            !ISwapIDKeeper(swapIDKeeper).isSwapCompleted(_swapID),
            "C3Caller: already completed"
        );
        context = Context({
            swapID: _swapID,
            fromChainID: _fromChainID,
            sourceTx: _sourceTx
        });

        (bool success, bytes memory result) = _to.call(_data);

        // try IC3CallExecutor(_to).execCall(_swapID, _data) returns (
        //     bool succ,
        //     bytes memory res
        // ) {
        //     (success, result) = (succ, res);
        // } catch Error(string memory reason) {
        //     result = bytes(reason);
        // } catch (bytes memory reason) {
        //     result = reason;
        // }
        context = Context({swapID: "", fromChainID: "", sourceTx: ""});

        emit LogExecCall(
            _dappID,
            _to,
            success,
            _swapID,
            _fromChainID,
            _sourceTx,
            _data,
            result
        );
        (bool ok, uint rs) = toUint(result);
        if (success && ok && rs == 1) {
            ISwapIDKeeper(swapIDKeeper).registerSwapin(_swapID);
        } else {
            emit LogFallbackCall(
                _dappID,
                _swapID,
                _fallback,
                abi.encodeWithSelector(
                    IC3Dapp.c3Fallback.selector,
                    _dappID,
                    _swapID,
                    _data,
                    result
                ),
                result
            );
        }
    }

    function c3Fallback(
        uint256 _dappID,
        bytes32 _swapID,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        bytes calldata _data,
        bytes calldata _reason
    ) external override onlyAuth {
        require(_data.length > 0, "C3Caller: empty calldata");
        require(
            !ISwapIDKeeper(swapIDKeeper).isSwapCompleted(_swapID),
            "C3Caller: already completed"
        );

        context = Context({
            swapID: _swapID,
            fromChainID: _fromChainID,
            sourceTx: _sourceTx
        });

        (bool success, bytes memory result) = _to.call(_data);

        context = Context({swapID: "", fromChainID: "", sourceTx: ""});

        emit LogExecFallback(
            _dappID,
            _to,
            success,
            _swapID,
            _fromChainID,
            _sourceTx,
            _reason,
            _data,
            result
        );

        (bool ok, uint rs) = toUint(result);

        if (success && ok && rs == 1) {
            ISwapIDKeeper(swapIDKeeper).registerSwapin(_swapID);
        }
    }

    function toUint(bytes memory bs) internal pure returns (bool, uint) {
        if (bs.length < 32) {
            return (false, 0);
        }
        uint x;
        assembly {
            x := mload(add(bs, add(0x20, 0)))
        }
        return (true, x);
    }
}