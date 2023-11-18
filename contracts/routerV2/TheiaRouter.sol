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

    modifier onlyMPC() {
        require(msg.sender == mpc(), "C3Router: MPC FORBIDDEN");
        _;
    }

    modifier onlyAuth() {
        require(isOperator[msg.sender], "C3ERC20: AUTH FORBIDDEN");
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
        require(newMPC != address(0), "C3Router: address(0)");
        _oldMPC = mpc();
        _newMPC = newMPC;
        _newMPCEffectiveTime = block.timestamp + DELAY;
        emit LogChangeMPC(_oldMPC, _newMPC, _newMPCEffectiveTime, cID());
        return true;
    }

    function _addOperator(address op) internal {
        require(op != address(0), "C3Router: Operator is address(0)");
        require(!isOperator[op], "C3Router: Operator already exists");
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
        require(isOperator[_auth], "C3Router: Operator not found");
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

    function checkSwapOut(address token, address to) internal pure {
        require(token != address(0), "C3Router: from address(0)");
        require(to != address(0), "C3Router: empty to address");
    }

    function checkC3Call(
        uint256 toChainID,
        string calldata to,
        string calldata dapp,
        bytes calldata data
    ) internal pure {
        require(toChainID > 0, "C3Call: empty toChainID");
        require(bytes(to).length > 0, "C3Call: empty to address");
        require(bytes(dapp).length > 0, "C3Call: empty dapp address");
        require(data.length > 0, "C3Call: empty c3 calldata");
    }

    // need approve to router first
    function _swapOutUnderlying(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        address _underlying = ITheiaERC20(token).underlying();
        require(_underlying != address(0), "C3Router: no underlying");
        uint256 old_balance = IERC20(_underlying).balanceOf(token);
        IERC20(_underlying).safeTransferFrom(msg.sender, token, amount);
        uint256 new_balance = IERC20(_underlying).balanceOf(token);
        require(
            new_balance >= old_balance && new_balance <= old_balance + amount
        );
        return new_balance - old_balance;
    }

    function _swapOutNative(address token) internal returns (uint256) {
        require(wNATIVE != address(0), "C3Router: zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "C3Router: underlying is not wNATIVE"
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

    function swapInAutoCallData(
        address _token,
        uint256 _amount,
        address _receiver,
        bytes32 _swapID
    ) external view returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "swapInAuto(bytes32,address,address,uint256,uint256)",
                _swapID,
                _token,
                _receiver,
                _amount,
                cID()
            );
    }

    function swapOut(
        address _token,
        uint256 _amount,
        address _to,
        address _receiver,
        uint256 _toChainID
    ) external {
        checkSwapOut(_token, _to);

        ITheiaERC20(_token).burn(msg.sender, _amount);
        uint256 swapFee = calcSwapFee(0, _toChainID, _token, _amount);
        if (swapFee > 0) {
            ITheiaERC20(_token).mint(address(this), swapFee);
        }
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
            _token,
            msg.sender,
            _amount,
            _receiver,
            _toChainID
        );

        bytes memory _data = abi.encodeWithSignature(
            "swapInAuto(bytes32,address,address,uint256,uint256)",
            swapID,
            _token,
            _receiver,
            _amount - swapFee,
            cID()
        );

        c3call(
            Strings.toHexString(_to),
            Strings.toHexString(_toChainID),
            _data
        );

        emit LogSwapOut(
            _token,
            msg.sender,
            Strings.toHexString(_receiver),
            _amount,
            cID(),
            _toChainID,
            swapFee,
            swapID,
            _data
        );
    }

    // function swapOutUnderlying(
    //     address token,
    //     string calldata to,
    //     uint256 amount,
    //     uint256 toChainID
    // ) external {
    //     checkSwapOut(token, to);
    //     bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
    //         token,
    //         msg.sender,
    //         to,
    //         amount,
    //         toChainID,
    //         "",
    //         ""
    //     );
    //     uint256 recvAmount = _swapOutUnderlying(token, amount);
    //     uint256 swapFee = calcSwapFee(0, toChainID, token, recvAmount);
    //     if (swapFee > 0) {
    //         ITheiaERC20(token).mint(address(this), swapFee);
    //     }
    //     emit LogSwapOut(
    //         token,
    //         msg.sender,
    //         to,
    //         recvAmount,
    //         cID(),
    //         toChainID,
    //         swapFee,
    //         swapID,
    //         "",
    //         ""
    //     );
    // }

    // function swapOutNative(
    //     address token,
    //     string calldata to,
    //     uint256 toChainID
    // ) external payable {
    //     checkSwapOut(token, to);
    //     uint256 recvAmount = _swapOutNative(token);
    //     bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
    //         token,
    //         msg.sender,
    //         to,
    //         recvAmount,
    //         toChainID,
    //         "",
    //         ""
    //     );
    //     uint256 swapFee = calcSwapFee(0, toChainID, token, recvAmount);
    //     if (swapFee > 0) {
    //         ITheiaERC20(token).mint(address(this), swapFee);
    //     }
    //     emit LogSwapOut(
    //         token,
    //         msg.sender,
    //         to,
    //         recvAmount,
    //         cID(),
    //         toChainID,
    //         swapFee,
    //         swapID,
    //         "",
    //         ""
    //     );
    // }

    // function swapOutAndCall(
    //     address token,
    //     string calldata to,
    //     uint256 amount,
    //     uint256 toChainID,
    //     string calldata dapp,
    //     bytes calldata data
    // ) external payable {
    //     checkC3Call(toChainID, to, dapp, data);
    //     bytes32 swapoutID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
    //         token,
    //         msg.sender,
    //         to,
    //         amount,
    //         toChainID,
    //         dapp,
    //         data
    //     );
    //     if (token != address(0)) {
    //         checkSwapOut(token, to);
    //         ITheiaERC20(token).burn(msg.sender, amount);
    //     }
    //     (, uint256 _srcFees) = IC3Caller(c3caller).checkCall(
    //         msg.sender,
    //         data.length,
    //         toChainID
    //     );

    //     if (_srcFees > 0) {
    //         _paySrcFees(_srcFees, 0);
    //     }

    //     emit LogSwapOut(
    //         token,
    //         msg.sender,
    //         to,
    //         amount,
    //         cID(),
    //         toChainID,
    //         0,
    //         swapoutID,
    //         dapp,
    //         data
    //     );
    // }

    // function swapOutUnderlyingAndCall(
    //     address token,
    //     string calldata to,
    //     uint256 amount,
    //     uint256 toChainID,
    //     string calldata dapp,
    //     bytes calldata data
    // ) external payable {
    //     checkC3Call(toChainID, to, dapp, data);
    //     bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
    //         token,
    //         msg.sender,
    //         to,
    //         amount,
    //         toChainID,
    //         dapp,
    //         data
    //     );
    //     uint256 recvAmount = 0;
    //     if (token != address(0)) {
    //         checkSwapOut(token, to);
    //         recvAmount = _swapOutUnderlying(token, amount);
    //     }

    //     (, uint256 _srcFees) = IC3Caller(c3caller).checkCall(
    //         msg.sender,
    //         data.length,
    //         toChainID
    //     );

    //     if (_srcFees > 0) {
    //         _paySrcFees(_srcFees, 0);
    //     }

    //     emit LogSwapOut(
    //         token,
    //         msg.sender,
    //         to,
    //         recvAmount,
    //         cID(),
    //         toChainID,
    //         0,
    //         swapID,
    //         dapp,
    //         data
    //     );
    // }

    // function swapOutNativeAndCall(
    //     address token,
    //     string calldata to,
    //     uint256 toChainID,
    //     string calldata dapp,
    //     bytes calldata data
    // ) external payable {
    //     checkC3Call(toChainID, to, dapp, data);
    //     uint256 recvAmount = 0;
    //     if (token != address(0)) {
    //         checkSwapOut(token, to);
    //         recvAmount = _swapOutNative(token);
    //     }
    //     bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
    //         token,
    //         msg.sender,
    //         to,
    //         recvAmount,
    //         toChainID,
    //         dapp,
    //         data
    //     );
    //     uint256 fee = 0;
    //     {
    //         (, uint256 _srcFees) = IC3Caller(c3caller).checkCall(
    //             msg.sender,
    //             data.length,
    //             toChainID
    //         );
    //         if (_srcFees > 0) {
    //             if (recvAmount > 0) {
    //                 ITheiaERC20(token).mint(address(this), _srcFees);
    //                 ITheiaERC20(token).withdrawVault(
    //                     address(this),
    //                     _srcFees,
    //                     address(this)
    //                 );
    //                 IwNATIVE(wNATIVE).withdraw(_srcFees);
    //             }
    //             _paySrcFees(_srcFees, recvAmount);
    //             fee = _srcFees;
    //         }
    //     }

    //     emit LogSwapOut(
    //         token,
    //         msg.sender,
    //         to,
    //         recvAmount,
    //         cID(),
    //         toChainID,
    //         fee,
    //         swapID,
    //         dapp,
    //         data
    //     );
    // }

    function _paySrcFees(uint256 fees, uint256 recvAmount) internal {
        require(msg.value >= fees, "C3Router: not enough src fee");
        // if (fees > 0) {
        //     // pay fees
        //     IC3Caller(c3caller).paySrcFees{value: fees}(msg.sender, fees);
        // }
        // if (msg.value - recvAmount > fees) {
        //     // return remaining amount
        //     (bool success, ) = msg.sender.call{value: msg.value - fees}("");
        //     require(success, "C3Router: failed to return remaining amount");
        // }
    }

    function _swapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string calldata sourceTx
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
        uint256 amount,
        uint256 fromChainID,
        string calldata sourceTx
    ) external onlyAuth {
        uint256 recvAmount = _swapIn(
            swapID,
            token,
            to,
            amount,
            fromChainID,
            sourceTx
        );
        ITheiaERC20 _anyToken = ITheiaERC20(token);
        address _underlying = _anyToken.underlying();
        if (
            _underlying != address(0) &&
            IERC20(_underlying).balanceOf(token) >= recvAmount
        ) {
            if (_underlying == wNATIVE) {
                _anyToken.withdrawVault(to, recvAmount, address(this));
                IwNATIVE(wNATIVE).withdraw(recvAmount);
                TransferHelper.safeTransferNative(to, recvAmount);
            } else {
                _anyToken.withdrawVault(to, recvAmount, to);
            }
        }
    }

    function _c3Fallback(
        uint256 dappID,
        bytes32 swapID,
        bytes calldata data,
        bytes calldata reason
    ) internal override {}

    function depositNative(
        address token,
        address to
    ) external payable returns (uint256) {
        require(wNATIVE != address(0), "C3Router: zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "C3Router: underlying is not wNATIVE"
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
        require(wNATIVE != address(0), "C3Router: zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "C3Router: underlying is not wNATIVE"
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
    function swapFeeTo(address[] calldata tokens) external onlyMPC {
        address _mpc = mpc();
        for (uint index = 0; index < tokens.length; index++) {
            address _token = tokens[index];
            uint256 amount = IERC20(_token).balanceOf(address(this));
            if (amount > 0) {
                ITheiaERC20(_token).withdrawVault(address(this), amount, _mpc);
            }
        }
    }

    // TODO: how to ensure that the fee config are both setted in fromChain and toChain correctly
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
        require(_fee < amount, "C3Router: Invalid FeeConfig");
        _fee = maximumSwapFee < _fee ? maximumSwapFee : _fee;
        _fee = minimumSwapFee > _fee ? minimumSwapFee : _fee;
        return _fee;
    }
}
