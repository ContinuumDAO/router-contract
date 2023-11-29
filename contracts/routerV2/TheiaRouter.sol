// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "../protocol/C3CallerDapp.sol";
import "./ISwapIDKeeper.sol";
import "./ITheiaERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// helper methods for interacting with ERC20 tokens and sending NATIVE that do not consistently return true/false
library TransferHelper {
    function safeTransferNative(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: NATIVE_TRANSFER_FAILED");
    }
}

interface IwNATIVE {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

contract TheiaRouter is C3CallerDapp {
    using Strings for *;
    using SafeERC20 for IERC20;

    address public constant factory = address(0);
    address public immutable wNATIVE;

    // delay for timelock functions
    uint public constant DELAY = 2 days;

    mapping(address => bool) public isOperator;
    address[] public operators;

    address public swapIDKeeper;

    constructor(
        address _wNATIVE,
        address _mpc,
        address _swapIDKeeper,
        address _c3callerProxy,
        uint256 _dappID
    ) C3CallerDapp(_c3callerProxy, _dappID) {
        _newMPC = _mpc;
        _newMPCEffectiveTime = block.timestamp;
        wNATIVE = _wNATIVE;
        swapIDKeeper = _swapIDKeeper;
        _addOperator(_mpc);
    }

    receive() external payable {}

    fallback() external payable {}

    address private _oldMPC;
    address private _newMPC;
    uint256 private _newMPCEffectiveTime;

    event LogChangeMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint indexed effectiveTime,
        uint256 chainID
    );
    event LogSwapIn(
        address indexed token,
        address indexed to,
        bytes32 indexed swapoutID,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        string sourceTx
    );
    event LogSwapOut(
        address indexed token,
        address indexed from,
        string to,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 fee,
        bytes32 swapoutID,
        bytes data
    );
    event LogAnySwapInAndExec(
        address indexed dapp,
        address indexed receiver,
        bytes32 swapID,
        address token,
        uint256 amount,
        uint256 fromChainID,
        string sourceTx,
        bool success,
        bytes result
    );

    event LogSwapFallback(
        bytes32 indexed swapID,
        address indexed token,
        address indexed receiver,
        uint256 amount,
        bytes4 selector,
        bytes data,
        bytes reason
    );

    modifier onlyMPC() {
        require(msg.sender == mpc(), "TR:MPC FORBIDDEN");
        _;
    }

    modifier onlyAuth() {
        require(
            isOperator[msg.sender] || isCaller(msg.sender),
            "C3ERC20: AUTH FORBIDDEN"
        );
        _;
    }

    modifier chargeDestFee(address _dapp) {
        uint256 _prevGasLeft = gasleft();
        _;
    }

    function mpc() public view returns (address) {
        if (block.timestamp >= _newMPCEffectiveTime) {
            return _newMPC;
        }
        return _oldMPC;
    }

    function cID() public view returns (uint) {
        return block.chainid;
    }

    function version() public pure returns (uint) {
        return 1;
    }

    function changeMPC(address newMPC) external onlyMPC returns (bool) {
        require(newMPC != address(0), "TR:address(0)");
        _oldMPC = mpc();
        _newMPC = newMPC;
        _newMPCEffectiveTime = block.timestamp + DELAY;
        emit LogChangeMPC(_oldMPC, _newMPC, _newMPCEffectiveTime, cID());
        return true;
    }

    function _addOperator(address op) internal {
        require(op != address(0), "TR:Operator is address(0)");
        require(!isOperator[op], "TR:Operator already exists");
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
        require(isOperator[_auth], "TR:Operator not found");
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

    function changeVault(
        address token,
        address newVault
    ) external onlyMPC returns (bool) {
        return ITheiaERC20(token).changeVault(newVault);
    }

    function changeSwapIDKeeper(address _swapIDKeeper) external onlyMPC {
        swapIDKeeper = _swapIDKeeper;
    }

    function setTokenFeeConfig(
        address token,
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom
    ) external onlyMPC returns (bool) {
        return
            ITheiaERC20(token).setFeeConfig(
                srcChainID,
                dstChainID,
                maxFee,
                minFee,
                feeRate,
                payFrom
            );
    }

    function setMinter(address token, address _auth) external onlyMPC {
        return ITheiaERC20(token).setMinter(_auth);
    }

    function applyMinter(address token) external onlyMPC {
        return ITheiaERC20(token).applyMinter();
    }

    function revokeMinter(address token, address _auth) external onlyMPC {
        return ITheiaERC20(token).revokeMinter(_auth);
    }

    function checkSwapOut(
        address token,
        address to,
        address receiver,
        uint256 amount
    ) internal pure {
        require(token != address(0), "TR:from empty");
        require(to != address(0), "TR:to empty");
        require(receiver != address(0), "TR:receiver empty");
        require(amount > 0, "TR:empty");
    }

    // need approve to router first
    function _swapOutUnderlying(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        address _underlying = ITheiaERC20(token).underlying();
        require(_underlying != address(0), "TR:no underlying");
        uint256 old_balance = IERC20(_underlying).balanceOf(token);
        IERC20(_underlying).safeTransferFrom(msg.sender, token, amount);
        uint256 new_balance = IERC20(_underlying).balanceOf(token);
        require(
            new_balance >= old_balance && new_balance <= old_balance + amount
        );
        return new_balance - old_balance;
    }

    function _swapOutNative(address token) internal returns (uint256) {
        require(wNATIVE != address(0), "TR:zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "TR:underlying is not wNATIVE"
        );
        uint256 old_balance = IERC20(wNATIVE).balanceOf(token);
        IwNATIVE(wNATIVE).deposit{value: msg.value}();
        IERC20(wNATIVE).safeTransfer(token, msg.value);
        uint256 new_balance = IERC20(wNATIVE).balanceOf(token);
        require(
            new_balance >= old_balance && new_balance <= old_balance + msg.value
        );
        return new_balance - old_balance;
    }

    function swapOutAuto(
        address _token,
        uint256 _amount,
        address _to,
        address _receiver,
        uint256 _toChainID
    ) external payable {
        checkSwapOut(_token, _to, _receiver, _amount);
        ITheiaERC20 theiaToken = ITheiaERC20(_token);
        address _underlying = theiaToken.underlying();
        uint256 _recvAmount = 0;
        if (_underlying != address(0)) {
            if (_underlying == wNATIVE && msg.value >= _amount) {
                _recvAmount = _swapOutNative(_token);
            } else {
                _recvAmount = _swapOutUnderlying(_token, _amount);
            }
        } else {
            ITheiaERC20(_token).burn(msg.sender, _amount);
            _recvAmount = _amount;
        }
        uint256 swapFee = calcSwapFee(0, _toChainID, _token, _recvAmount);
        if (swapFee > 0) {
            ITheiaERC20(_token).mint(address(this), swapFee);
        }

        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
            _token,
            msg.sender,
            _recvAmount,
            _receiver,
            _toChainID
        );

        bytes memory _data = abi.encodeWithSignature(
            "swapInAuto(bytes32,address,address,uint256)",
            swapID,
            _token,
            _receiver,
            _recvAmount - swapFee
        );

        c3call(_to.toHexString(), _toChainID.toString(), _data);

        emit LogSwapOut(
            _token,
            msg.sender,
            _receiver.toHexString(),
            _recvAmount,
            cID(),
            _toChainID,
            swapFee,
            swapID,
            _data
        );
    }

    function callAndSwapOut(
        address _fromToken,
        uint256 _amount,
        address _to,
        address _toToken,
        address _receiver,
        uint256 _toChainID,
        address _dexAddr,
        bytes calldata _data
    ) external payable {
        checkSwapOut(_fromToken, _to, _receiver, _amount);
        require(_toToken != address(0), "TR:_toToken empty");
        require(_dexAddr != address(0), "TR:_dexAddr empty");
        ITheiaERC20 toTheiaToken = ITheiaERC20(_toToken);
        require(toTheiaToken.underlying() != address(0), "TR:underlying empty");
        require(
            IERC20(toTheiaToken.underlying()).balanceOf(address(this)) == 0,
            "TR:underlying amount >0"
        );

        bool success;
        bytes memory result;
        ITheiaERC20 theiaToken = ITheiaERC20(_fromToken);
        address _underlying = theiaToken.underlying();
        if (
            _underlying != address(0) &&
            IERC20(_fromToken).balanceOf(msg.sender) < _amount
        ) {
            if (_underlying == wNATIVE) {
                require(msg.value >= _amount, "TR:balance not enough");
                (success, result) = _dexAddr.call{value: msg.value}(_data);
            } else {
                require(
                    IERC20(_underlying).balanceOf(msg.sender) >= _amount,
                    "TR:balance not enough"
                );
                IERC20(_underlying).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _amount
                );
                IERC20(_underlying).approve(_dexAddr, _amount);
                (success, result) = _dexAddr.call(_data);
            }
        } else {
            require(
                IERC20(_fromToken).balanceOf(msg.sender) >= _amount,
                "TR:balance not enough"
            );
            ITheiaERC20(_fromToken).burn(msg.sender, _amount);
            ITheiaERC20(_fromToken).mint(address(this), _amount);
            IERC20(_fromToken).approve(_dexAddr, _amount);
            (success, result) = _dexAddr.call(_data);
        }

        if (success) {
            require(
                IERC20(toTheiaToken.underlying()).balanceOf(address(this)) > 0,
                "TR:nothing received"
            );
        }
        uint256 amount = IERC20(toTheiaToken.underlying()).balanceOf(
            address(this)
        );

        uint256 swapFee = calcSwapFee(0, _toChainID, _toToken, amount);
        if (swapFee > 0) {
            ITheiaERC20(toTheiaToken).mint(address(this), swapFee);
        }

        bytes32 _swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
            _toToken,
            msg.sender,
            amount,
            _receiver,
            _toChainID
        );

        bytes memory data = abi.encodeWithSignature(
            "swapInAuto(bytes32,address,address,uint256)",
            _swapID,
            _toToken,
            _receiver,
            amount - swapFee
        );

        c3call(_to.toHexString(), _toChainID.toString(), data);

        emit LogSwapOut(
            _toToken,
            msg.sender,
            _receiver.toHexString(),
            amount,
            cID(),
            _toChainID,
            swapFee,
            _swapID,
            data
        );
    }

    function swapOutAndCall(
        address _token,
        uint256 _amount,
        address _to,
        address _receiver,
        uint256 _toChainID,
        bool _native,
        address _dex,
        bytes calldata _data
    ) external payable {
        checkSwapOut(_token, _to, _receiver, _amount);
        require(_dex != address(0), "TR:dex empty");
        require(_data.length > 0, "TR:data empty");

        uint256 recvAmount = 0;
        ITheiaERC20 theiaToken = ITheiaERC20(_token);
        address _underlying = theiaToken.underlying();
        if (
            _underlying != address(0) &&
            IERC20(_token).balanceOf(msg.sender) < _amount
        ) {
            if (_underlying == wNATIVE) {
                require(msg.value >= _amount, "TR:not enough");
                recvAmount = _swapOutNative(_token);
            } else {
                require(
                    IERC20(_underlying).balanceOf(msg.sender) >= _amount,
                    "TR:not enough"
                );
                recvAmount = _swapOutUnderlying(_token, _amount);
            }
        } else {
            require(
                IERC20(_token).balanceOf(msg.sender) >= _amount,
                "TR:not enough"
            );
            ITheiaERC20(_token).burn(msg.sender, _amount);
            recvAmount = _amount;
        }
        uint256 swapFee = calcSwapFee(0, _toChainID, _token, recvAmount);
        if (swapFee > 0) {
            ITheiaERC20(_token).mint(address(this), swapFee);
        }
        bytes32 _swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
            _token,
            msg.sender,
            _amount,
            _receiver,
            _toChainID
        );

        bytes memory data = abi.encodeWithSignature(
            "swapInAutoAndCall(bytes32,address,bool,address,uint256,address,bytes)",
            _swapID,
            _token,
            _native,
            _receiver,
            recvAmount - swapFee,
            _dex,
            _data
        );
        c3call(_to.toHexString(), _toChainID.toString(), data);

        emit LogSwapOut(
            _token,
            msg.sender,
            _receiver.toHexString(),
            _amount,
            cID(),
            _toChainID,
            swapFee,
            _swapID,
            data
        );
    }

    function _swapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string memory sourceTx
    ) internal returns (uint256) {
        ISwapIDKeeper(swapIDKeeper).registerSwapin(swapID);
        uint256 swapFee = calcSwapFee(fromChainID, 0, token, amount);
        if (swapFee > 0) {
            ITheiaERC20(token).mint(address(this), swapFee);
        }
        ITheiaERC20(token).mint(to, amount - swapFee);
        emit LogSwapIn(
            token,
            to,
            swapID,
            amount - swapFee,
            fromChainID,
            cID(),
            sourceTx
        );
        return amount - swapFee;
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID with `to` receiving `underlying` if possible
    function swapInAuto(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount
    ) external onlyAuth returns (bool) {
        (, string memory fromChainID, string memory _sourceTx) = context();

        (uint256 sourceChainID, bool ok) = strToUint(fromChainID);
        require(ok, "TR:sourceChain invalid");

        uint256 recvAmount = _swapIn(
            swapID,
            token,
            to,
            amount,
            sourceChainID,
            _sourceTx
        );
        return _swapAuto(token, to, recvAmount);
    }

    function _swapAuto(
        address token,
        address to,
        uint256 recvAmount
    ) internal returns (bool) {
        ITheiaERC20 theiaToken = ITheiaERC20(token);
        address _underlying = theiaToken.underlying();
        if (_underlying != address(0)) {
            // TODO is it allowed to just mint veToken if underlying is insufficient?
            require(
                IERC20(_underlying).balanceOf(token) >= recvAmount,
                "TR:insufficient balance"
            );
            if (_underlying == wNATIVE) {
                theiaToken.withdrawVault(to, recvAmount, address(this));
                IwNATIVE(wNATIVE).withdraw(recvAmount);
                TransferHelper.safeTransferNative(to, recvAmount);
            } else {
                theiaToken.withdrawVault(to, recvAmount, to);
            }
        }
        return true;
    }

    function swapInAutoAndCall(
        bytes32 swapID,
        address token,
        bool native,
        address to,
        uint256 amount,
        address dex,
        bytes memory data
    ) external onlyAuth returns (bool) {
        (, string memory fromChainID, string memory _sourceTx) = context();

        (uint256 sourceChainID, bool ok) = strToUint(fromChainID);
        require(ok, "TR:sourceChain is invalid");

        uint256 recvAmount = _swapIn(
            swapID,
            token,
            to,
            amount,
            sourceChainID,
            _sourceTx
        );

        ITheiaERC20 theiaToken = ITheiaERC20(token);
        address _underlying = theiaToken.underlying();

        bool success;
        bytes memory result;
        if (
            _underlying != address(0) &&
            IERC20(_underlying).balanceOf(token) >= recvAmount
        ) {
            theiaToken.withdrawVault(to, recvAmount, address(this));
            if (_underlying == wNATIVE && native) {
                IwNATIVE(wNATIVE).withdraw(recvAmount);
                (success, result) = dex.call{value: recvAmount}(data);
            } else {
                IERC20(_underlying).approve(dex, recvAmount); // safeApprove?
                (success, result) = dex.call(data);
            }
        } else {
            theiaToken.burn(to, recvAmount);
            theiaToken.mint(address(this), recvAmount);
            IERC20(token).approve(dex, recvAmount);
            (success, result) = dex.call(data);
        }

        // require(success, "TR:swapInAutoAndCall failed");
        return success;
    }

    function _c3Fallback(
        bytes4 _selector,
        bytes calldata _data,
        bytes calldata _reason
    ) internal override returns (bool) {
        (
            bytes32 _swapID,
            address _token,
            address _receiver,
            uint256 _amount
        ) = abi.decode(_data, (bytes32, address, address, uint256));

        require(
            ISwapIDKeeper(swapIDKeeper).isSwapoutIDExist(_swapID),
            "TR:swapId not exists"
        );
        ISwapIDKeeper(swapIDKeeper).registerSwapin(_swapID);
        ITheiaERC20(_token).mint(_receiver, _amount);

        emit LogSwapFallback(
            _swapID,
            _token,
            _receiver,
            _amount,
            _selector,
            _data,
            _reason
        );
        return _swapAuto(_token, _receiver, _amount);
    }

    function depositNative(
        address token,
        address to
    ) external payable returns (uint256) {
        require(wNATIVE != address(0), "TR:zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "TR:underlying is not wNATIVE"
        );
        IwNATIVE(wNATIVE).deposit{value: msg.value}();
        assert(IwNATIVE(wNATIVE).transfer(token, msg.value));
        ITheiaERC20(token).depositVault(msg.value, to);
        return msg.value;
    }

    function withdrawNative(
        address token,
        uint256 amount,
        address to
    ) external returns (uint256) {
        require(wNATIVE != address(0), "TR:zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "TR:underlying is not wNATIVE"
        );

        uint256 old_balance = IERC20(wNATIVE).balanceOf(address(this));
        ITheiaERC20(token).withdrawVault(msg.sender, amount, address(this));
        uint256 new_balance = IERC20(wNATIVE).balanceOf(address(this));
        assert(new_balance == old_balance + amount);

        IwNATIVE(wNATIVE).withdraw(amount);
        TransferHelper.safeTransferNative(to, amount);
        return amount;
    }

    //  extracts mpc fee from bridge fees
    function withdrawFee(address[] calldata tokens) external onlyMPC {
        address _mpc = mpc();
        for (uint index = 0; index < tokens.length; index++) {
            address _token = tokens[index];
            uint256 amount = IERC20(_token).balanceOf(address(this));
            if (amount > 0) {
                ITheiaERC20(_token).withdrawVault(address(this), amount, _mpc);
            }
        }
    }

    function calcSwapFee(
        uint256 fromChainID,
        uint256 toChainID,
        address token,
        uint256 amount
    ) public view returns (uint256) {
        (
            uint256 maximumSwapFee,
            uint256 minimumSwapFee,
            uint256 swapFeeRatePerMillion
        ) = ITheiaERC20(token).getFeeConfig(fromChainID, toChainID);
        if (swapFeeRatePerMillion == 0) return 0;
        if (maximumSwapFee > 0 && maximumSwapFee == minimumSwapFee)
            return maximumSwapFee;
        uint256 _fee = (amount * swapFeeRatePerMillion) / 1000000;
        require(_fee < amount, "TR:Invalid FeeConfig");
        _fee = maximumSwapFee < _fee ? maximumSwapFee : _fee;
        _fee = minimumSwapFee > _fee ? minimumSwapFee : _fee;
        return _fee;
    }

    function strToUint(
        string memory _str
    ) public pure returns (uint256 res, bool err) {
        if (bytes(_str).length == 0) {
            return (0, true);
        }
        for (uint256 i = 0; i < bytes(_str).length; i++) {
            if (
                (uint8(bytes(_str)[i]) - 48) < 0 ||
                (uint8(bytes(_str)[i]) - 48) > 9
            ) {
                return (0, false);
            }
            res +=
                (uint8(bytes(_str)[i]) - 48) *
                10 ** (bytes(_str).length - i - 1);
        }

        return (res, true);
    }
}
