// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IC3Caller.sol";
import "./ISwapIDKeeper.sol";
import "./C3GovClient.sol";

contract C3Caller is IC3Caller, C3GovClient {
    struct Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
        bytes reason;
    }

    Context public override context;

    address public swapIDKeeper;

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
        initGov(_gov);
        swapIDKeeper = _swapIDKeeper;
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
        C3CallerStructLib.C3EvmMessage calldata _message
    ) external override onlyOperator {
        require(_message.data.length > 0, "C3Caller: empty calldata");
        // check dappID
        require(
            IC3Dapp(_message.to).dappID() == _dappID,
            "C3Caller: dappID dismatch"
        );
        require(
            !ISwapIDKeeper(swapIDKeeper).isSwapCompleted(_message.uuid),
            "C3Caller: already completed"
        );

        context = Context({
            swapID: _message.uuid,
            fromChainID: _message.fromChainID,
            sourceTx: _message.sourceTx,
            reason: ""
        });

        (bool success, bytes memory result) = _message.to.call(_message.data);

        context = Context({
            swapID: "",
            fromChainID: "",
            sourceTx: "",
            reason: ""
        });

        emit LogExecCall(
            _dappID,
            _message.to,
            _message.uuid,
            _message.fromChainID,
            _message.sourceTx,
            _message.data,
            success,
            result
        );
        (bool ok, uint rs) = toUint(result);
        if (success && ok && rs == 1) {
            ISwapIDKeeper(swapIDKeeper).registerSwapin(_message.uuid);
        } else {
            emit LogFallbackCall(
                _dappID,
                _message.uuid,
                _message.fallbackTo,
                abi.encodeWithSelector(
                    IC3Dapp.c3Fallback.selector,
                    _dappID,
                    _message.data,
                    result
                )
            );
        }
    }

    function c3Fallback(
        uint256 _dappID,
        C3CallerStructLib.C3EvmFallbackMessage calldata _message
    ) external override onlyOperator {
        require(_message.data.length > 0, "C3Caller: empty calldata");
        require(
            !ISwapIDKeeper(swapIDKeeper).isSwapCompleted(_message.uuid),
            "C3Caller: already completed"
        );

        context = Context({
            swapID: _message.uuid,
            fromChainID: _message.fromChainID,
            sourceTx: _message.sourceTx,
            reason: _message.reason
        });

        (bool _success, bytes memory _result) = _message.to.call(_message.data);

        context = Context({
            swapID: "",
            fromChainID: "",
            sourceTx: "",
            reason: ""
        });

        emit LogExecFallback(
            _dappID,
            _message.to,
            _success,
            _message.uuid,
            _message.fromChainID,
            _message.sourceTx,
            _message.reason,
            _message.data,
            _result
        );

        (bool ok, uint rs) = toUint(_result);
        if (_success && ok && rs == 1) {
            ISwapIDKeeper(swapIDKeeper).registerSwapin(_message.uuid);
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
