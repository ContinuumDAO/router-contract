// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IC3Caller.sol";
import "./ISwapIDKeeper.sol";

contract C3Caller is IC3Caller {
    struct Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
        bytes reason;
    }

    Context public override context;

    address public gov;
    address public pendingGov;

    mapping(address => bool) public isOperator;
    address[] public operators;

    address public swapIDKeeper;

    /// @dev Access control function
    modifier onlyGov() {
        require(msg.sender == gov, "C3Caller: only Gov");
        _;
    }

    modifier onlyOperator() {
        require(isOperator[msg.sender], "C3Caller: AUTH FORBIDDEN");
        _;
    }

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

    event LogC3Call(
        uint256 indexed dappID,
        bytes32 indexed uuid,
        address caller,
        string toChainID,
        string to,
        bytes data
    );

    event LogFallbackCall(
        uint256 indexed dappID,
        bytes32 indexed uuid,
        string to,
        bytes data
    );

    event LogExecCall(
        uint256 indexed dappID,
        address indexed to,
        bytes32 indexed uuid,
        string fromChainID,
        string sourceTx,
        bytes data,
        bool success,
        bytes reasons
    );

    event LogExecFallback(
        uint256 indexed dappID,
        address indexed to,
        bool indexed success,
        bytes32 uuid,
        string fromChainID,
        string sourceTx,
        bytes fallbackReason,
        bytes data,
        bytes reasons
    );

    constructor(address _gov, address _swapIDKeeper) {
        require(_gov != address(0));
        gov = _gov;
        swapIDKeeper = _swapIDKeeper;
        _addOperator(_gov);
        emit ApplyGov(address(0), _gov, block.timestamp);
    }

    function changeGov(address _gov) external onlyGov {
        pendingGov = _gov;
        emit ChangeGov(gov, _gov, block.timestamp);
    }

    function applyGov() external {
        require(msg.sender == pendingGov);
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

    function addOperator(address _auth) external onlyGov {
        _addOperator(_auth);
    }

    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }

    function revokeOperator(address _auth) external onlyGov {
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
        bytes32 _uuid = ISwapIDKeeper(swapIDKeeper).genUUID(
            _dappID,
            _to,
            _toChainID,
            _data
        );
        emit LogC3Call(_dappID, _uuid, _caller, _toChainID, _to, _data);
    }

    function c3broadcast(
        uint256 _dappID,
        address _caller,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) external override {
        require(_dappID > 0, "C3Caller: empty dappID");
        require(_to.length > 0, "C3Caller: empty _to");
        require(_toChainIDs.length > 0, "C3Caller: empty toChainID");
        require(_data.length > 0, "C3Caller: empty calldata");
        require(
            _data.length == _toChainIDs.length,
            "C3Caller: calldata length dismatch"
        );

        for (uint256 i = 0; i < _toChainIDs.length; i++) {
            bytes32 _uuid = ISwapIDKeeper(swapIDKeeper).genUUID(
                _dappID,
                _to[i],
                _toChainIDs[i],
                _data
            );
            emit LogC3Call(
                _dappID,
                _uuid,
                _caller,
                _toChainIDs[i],
                _to[i],
                _data
            );
        }
    }

    function execute(
        uint256 _dappID,
        bytes32 _uuid,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        string calldata _fallback,
        bytes calldata _data
    ) external override onlyOperator {
        require(_data.length > 0, "C3Caller: empty calldata");
        // check dappID
        require(IC3Dapp(_to).dappID() == _dappID, "C3Caller: dappID dismatch");
        require(
            !ISwapIDKeeper(swapIDKeeper).isSwapCompleted(_uuid),
            "C3Caller: already completed"
        );

        context = Context({
            swapID: _uuid,
            fromChainID: _fromChainID,
            sourceTx: _sourceTx,
            reason: ""
        });

        (bool success, bytes memory result) = _to.call(_data);

        context = Context({
            swapID: "",
            fromChainID: "",
            sourceTx: "",
            reason: ""
        });

        emit LogExecCall(
            _dappID,
            _to,
            _uuid,
            _fromChainID,
            _sourceTx,
            _data,
            success,
            result
        );
        (bool ok, uint rs) = toUint(result);
        if (success && ok && rs == 1) {
            ISwapIDKeeper(swapIDKeeper).registerSwapin(_uuid);
        } else {
            emit LogFallbackCall(
                _dappID,
                _uuid,
                _fallback,
                abi.encodeWithSelector(
                    IC3Dapp.c3Fallback.selector,
                    _dappID,
                    _data,
                    result
                )
            );
        }
    }

    function c3Fallback(
        uint256 _dappID,
        bytes32 _uuid,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        bytes calldata _data,
        bytes calldata _reason
    ) external override onlyOperator {
        require(_data.length > 0, "C3Caller: empty calldata");
        require(
            !ISwapIDKeeper(swapIDKeeper).isSwapCompleted(_uuid),
            "C3Caller: already completed"
        );

        context = Context({
            swapID: _uuid,
            fromChainID: _fromChainID,
            sourceTx: _sourceTx,
            reason: _reason
        });

        (bool _success, bytes memory _result) = _to.call(_data);

        context = Context({
            swapID: "",
            fromChainID: "",
            sourceTx: "",
            reason: ""
        });

        emit LogExecFallback(
            _dappID,
            _to,
            _success,
            _uuid,
            _fromChainID,
            _sourceTx,
            _reason,
            _data,
            _result
        );

        // TODO return bool is good?
        (bool ok, uint rs) = toUint(_result);
        if (_success && ok && rs == 1) {
            ISwapIDKeeper(swapIDKeeper).registerSwapin(_uuid);
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
