// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "./TheiaUtils.sol";
import "./ISwapIDKeeper.sol";
import "./ITheiaERC20.sol";
import "./FeeManager.sol";
import "./ITheiaConfig.sol";
import "./TransferHelper.sol";
import "./IwNATIVE.sol";
import "./IRouter.sol";
import "./TheiaStruct.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TheiaRouter is IRouter, FeeManager {
    using Strings for *;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable wNATIVE;

    address public swapIDKeeper;
    address public theiaConfig;

    constructor(
        address _wNATIVE,
        address _swapIDKeeper,
        address _theiaConfig,
        address _feeToken,
        address _gov,
        address _c3callerProxy,
        uint256 _dappID
    ) FeeManager(_feeToken, _gov, _c3callerProxy, _dappID) {
        wNATIVE = _wNATIVE;
        swapIDKeeper = _swapIDKeeper;
        theiaConfig = _theiaConfig;
    }

    receive() external payable {}

    fallback() external payable {}

    modifier chargeDestFee(address _dapp) {
        uint256 _prevGasLeft = gasleft();
        _;
    }

    function cID() public view returns (uint) {
        return block.chainid;
    }

    function version() public pure returns (uint) {
        return 1;
    }

    function changeSwapIDKeeper(address _swapIDKeeper) external onlyGov {
        swapIDKeeper = _swapIDKeeper;
    }

    function setMinter(address token, address _auth) external onlyGov {
        return ITheiaERC20(token).setMinter(_auth);
    }

    function applyMinter(address token) external onlyGov {
        return ITheiaERC20(token).applyMinter();
    }

    function revokeMinter(address token, address _auth) external onlyGov {
        return ITheiaERC20(token).revokeMinter(_auth);
    }

    function checkSwapOut(
        address token,
        address to,
        address receiver,
        uint256 amount
    ) internal pure {
        require(token != address(0), "Theia:from empty");
        require(to != address(0), "Theia:to empty");
        require(receiver != address(0), "Theia:receiver empty");
        require(amount > 0, "Theia:empty");
    }

    // need approve to router first
    function _swapOutUnderlying(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        address _underlying = ITheiaERC20(token).underlying();
        require(_underlying != address(0), "Theia:no underlying");
        uint256 old_balance = IERC20(_underlying).balanceOf(token);
        IERC20(_underlying).safeTransferFrom(msg.sender, token, amount);
        uint256 new_balance = IERC20(_underlying).balanceOf(token);
        require(
            new_balance >= old_balance && new_balance <= old_balance + amount,
            "Theia:get wrong"
        );
        return new_balance - old_balance;
    }

    function _swapOutNative(address token) internal returns (uint256) {
        require(wNATIVE != address(0), "Theia:zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "Theia:underlying is not wNATIVE"
        );
        uint256 old_balance = IERC20(wNATIVE).balanceOf(token);
        IwNATIVE(wNATIVE).deposit{value: msg.value}();
        IERC20(wNATIVE).safeTransfer(token, msg.value);
        uint256 new_balance = IERC20(wNATIVE).balanceOf(token);
        require(
            new_balance >= old_balance &&
                new_balance <= old_balance + msg.value,
            "Theia:get wrong"
        );
        return new_balance - old_balance;
    }

    function _getRevAmount(
        address _token,
        uint256 _amount
    ) internal returns (uint256) {
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
            theiaToken.burn(msg.sender, _amount);
            _recvAmount = _amount;
        }
        return _recvAmount;
    }

    function getLiquidity(
        address token
    ) external view returns (uint256, uint256) {
        return _getLiquidity(token);
    }

    function _getLiquidity(
        address token
    ) internal view returns (uint256, uint256) {
        address underlying = ITheiaERC20(token).underlying();
        if (underlying == address(0)) {
            return (0, 0);
        }
        uint256 liquidity = IERC20(underlying).balanceOf(token);
        uint256 decimals = IERC20Extended(underlying).decimals();

        return (liquidity, decimals);
    }

    function queryLiquidityFeeRate(
        address _theiaToken,
        uint256 _amount
    ) public view returns (uint256) {
        (uint256 _liquidity, uint256 _decimals) = _getLiquidity(_theiaToken);
        uint256 _feeRate = 0;
        if (_decimals > 0) {
            _feeRate = _getFeeFactor(_liquidity, _amount);
        }
        return _feeRate;
    }

    function _calcAndPay(
        address _feeToken,
        uint256 _toChainID
    ) internal returns (uint256) {
        uint256 feeReadable = getGasFee(cID(), _toChainID, _feeToken);
        if (feeReadable > 0) {
            uint256 _swapFee = convertDecimals(
                feeReadable,
                2,
                ITheiaERC20(_feeToken).decimals()
            );

            _payFee(_feeToken, _swapFee);
            return _swapFee;
        }
        return 0;
    }

    function swapOutAuto(
        address _to,
        address _receiver,
        uint256 _amount,
        uint256 _feeAmount,
        uint256 _toChainID,
        string memory _tokenID,
        string memory _feeTokenID
    ) external payable {
        (
            Structs.TokenConfig memory _fromConfig,
            Structs.TokenConfig memory _toConfig
        ) = ITheiaConfig(theiaConfig).getTokenConfigIfExist(
                _tokenID,
                _toChainID
            );
        require(
            _fromConfig.Decimals > 0 && _toConfig.Decimals > 0,
            "Theia:token not support"
        );

        (
            Structs.TokenConfig memory _fromFeeConfig,
            Structs.TokenConfig memory _toFeeConfig
        ) = ITheiaConfig(theiaConfig).getTokenConfigIfExist(
                _feeTokenID,
                _toChainID
            );
        require(
            _fromFeeConfig.Decimals > 0 && _toFeeConfig.Decimals > 0,
            "Theia:token not support"
        );

        address _token = TheiaUtils.toAddress(_fromConfig.ContractAddress);
        address _recToken = TheiaUtils.toAddress(_toConfig.ContractAddress);
        uint8 _recDecimals = _toConfig.Decimals;
        checkSwapOut(_token, _to, _receiver, _amount);
        require(_recToken != address(0), "Theia:recToken empty");
        uint256 _recvAmount = _getRevAmount(_token, _amount);
        require(_recvAmount > 0, "Theia:nothing to cross");

        address _feeToken = TheiaUtils.toAddress(
            _fromFeeConfig.ContractAddress
        );
        uint256 _swapFee = _calcAndPay(_feeToken, _toChainID);
        require(_feeAmount >= _swapFee, "Theia:fee not enough");

        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
            _token,
            msg.sender,
            _recvAmount,
            _receiver,
            _toChainID
        );

        uint256 _toAmount = _recvAmount;

        if (ITheiaERC20(_token).decimals() != _recDecimals) {
            _toAmount = convertDecimals(
                _toAmount,
                ITheiaERC20(_token).decimals(),
                _recDecimals
            );
            require(_toAmount > 0, "Theia:wrong Decimals");
        }

        uint256 _liquidityFee = _feeAmount - _swapFee;
        if (
            _liquidityFee > 0 &&
            ITheiaERC20(_feeToken).decimals() != _toFeeConfig.Decimals
        ) {
            _liquidityFee = convertDecimals(
                _liquidityFee,
                ITheiaERC20(_feeToken).decimals(),
                _toFeeConfig.Decimals
            );
            require(_liquidityFee > 0, "Theia:wrong Decimals");
        }

        bytes memory _data = abi.encodeWithSelector(
            TheiaStruct.FuncSwapInAuto,
            swapID,
            _recToken,
            _receiver,
            _toAmount,
            _recDecimals,
            _liquidityFee,
            _feeToken,
            _token
        );

        c3call(_to.toHexString(), _toChainID.toString(), _data);

        emit LogSwapOut(
            _token,
            msg.sender,
            swapID,
            _recvAmount,
            cID(),
            _toChainID,
            _swapFee,
            _feeToken,
            _receiver.toHexString()
        );
    }

    function swapInAuto(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 tokenDecimals,
        uint256 feePaid,
        address feeToken,
        address fromTokenAddr
    ) external onlyGov returns (bool) {
        require(token != address(0), "Theia:token empty");
        require(swapID.length > 0, "Theia:swapID empty");
        require(to != address(0), "Theia:to empty");
        require(amount > 0, "Theia:amount empty");
        require(tokenDecimals > 0, "Theia:tokenDecimals empty");
        require(fromTokenAddr != address(0), "Theia:fromTokenAddr empty");

        (, string memory fromChainID, string memory _sourceTx, ) = context();

        (uint256 sourceChainID, bool ok) = strToUint(fromChainID);
        require(ok, "Theia:sourceChain invalid");

        require(
            ITheiaERC20(token).decimals() == tokenDecimals,
            "Theia:tokenDecimals dismatch"
        );

        uint256 feeRate = queryLiquidityFeeRate(token, amount);
        if (feeRate > 0) {
            uint256 baseFee = getBaseLiquidityFee(feeToken);
            require(baseFee > 0, "Theia:config error");
            uint256 fee = (baseFee * feeRate) / 1000;
            require(feePaid >= fee, "Theia:not cover liquidity fee");
        }

        uint256 recvAmount = _registerAndMint(
            swapID,
            token,
            to,
            amount,
            sourceChainID,
            _sourceTx
        );
        return _swapAuto(token, to, recvAmount);
    }

    function _registerAndMint(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string memory sourceTx
    ) internal returns (uint256) {
        ISwapIDKeeper(swapIDKeeper).registerSwapin(swapID);
        ITheiaERC20(token).mint(to, amount);
        emit LogSwapIn(token, to, swapID, amount, fromChainID, cID(), sourceTx);
        return amount;
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
                "Theia:insufficient balance"
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

    function _c3Fallback(
        bytes4 _selector,
        bytes calldata _data,
        bytes calldata _reason
    ) internal override returns (bool) {
        bytes32 _swapID;
        address _receiver;
        uint256 _amount;
        uint256 _recDecimals;
        address _fromToken;
        (_swapID, , _receiver, _amount, _recDecimals, _fromToken) = abi.decode(
            _data,
            (bytes32, address, address, uint256, uint256, address)
        );

        require(
            ISwapIDKeeper(swapIDKeeper).isSwapoutIDExist(_swapID),
            "Theia:swapId not exists"
        );
        ISwapIDKeeper(swapIDKeeper).registerSwapin(_swapID);

        uint256 _toAmount = _amount;
        if (ITheiaERC20(_fromToken).decimals() != _recDecimals) {
            _toAmount = convertDecimals(
                _amount,
                _recDecimals,
                ITheiaERC20(_fromToken).decimals()
            );
        }
        require(_toAmount > 0, "Theia:recAmount convert err");

        ITheiaERC20(_fromToken).mint(_receiver, _toAmount);

        emit LogSwapFallback(
            _swapID,
            _fromToken,
            _receiver,
            _toAmount,
            _selector,
            _data,
            _reason
        );
        return _swapAuto(_fromToken, _receiver, _toAmount);
    }

    function depositNative(
        address token,
        address to
    ) external payable returns (uint256) {
        require(wNATIVE != address(0), "Theia:zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "Theia:underlying is not wNATIVE"
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
        require(wNATIVE != address(0), "Theia:zero wNATIVE");
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "Theia:underlying is not wNATIVE"
        );

        uint256 old_balance = IERC20(wNATIVE).balanceOf(address(this));
        ITheiaERC20(token).withdrawVault(msg.sender, amount, address(this));
        uint256 new_balance = IERC20(wNATIVE).balanceOf(address(this));
        assert(new_balance == old_balance + amount);

        IwNATIVE(wNATIVE).withdraw(amount);
        TransferHelper.safeTransferNative(to, amount);
        return amount;
    }

    //  extracts gov fee from bridge fees
    function withdrawFee(address[] calldata tokens) external onlyGov {
        address _gov = gov();
        for (uint index = 0; index < tokens.length; index++) {
            address _token = tokens[index];
            uint256 amount = IERC20(_token).balanceOf(address(this));
            if (amount > 0) {
                ITheiaERC20(_token).withdrawVault(address(this), amount, _gov);
            }
        }
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

    function convertDecimals(
        uint256 amount,
        uint256 from,
        uint256 to
    ) public pure returns (uint256) {
        if (from == to) return amount;
        if (from > to) {
            //uint256 res = from.sub(to);
            uint256 res = from - to;
            (bool ok, uint256 rtn) = amount.tryDiv(10 ** res);
            if (ok) return rtn;
            return 0;
        } else {
            //uint256 res = to.sub(from);
            uint256 res = to - from;
            (bool ok, uint256 rtn) = amount.tryMul(10 ** res);
            if (ok) return rtn;
            return 0;
        }
    }

    function _balanceOf(address receiveToken) internal view returns (uint256) {
        return IERC20(receiveToken).balanceOf(address(this));
    }
}
