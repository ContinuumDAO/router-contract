// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "./TheiaUtils.sol";
import "./ITheiaUUIDKeeper.sol";
import "./ITheiaERC20.sol";
import "./IFeeManager.sol";
import "./ITheiaConfig.sol";
import "./TransferHelper.sol";
import "./IwNATIVE.sol";
import "./IRouter.sol";
import "./GovernDapp.sol";
import "./TheiaStruct.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TheiaRouter is IRouter, GovernDapp {
    using Strings for *;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable wNATIVE;

    address public uuidKeeper;
    address public theiaConfig;
    address public feeManager;

    constructor(
        address _wNATIVE,
        address _uuidKeeper,
        address _theiaConfig,
        address _feeManager,
        address _gov,
        address _c3callerProxy,
        address _txSender,
        uint256 _dappID
    ) GovernDapp(_gov, _c3callerProxy, _txSender, _dappID) {
        wNATIVE = _wNATIVE;
        uuidKeeper = _uuidKeeper;
        theiaConfig = _theiaConfig;
        feeManager = _feeManager;
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

    function changeUUIDKeeper(address _uuidKeeper) external onlyGov {
        uuidKeeper = _uuidKeeper;
        emit LogChangeUUIDKeeper(_uuidKeeper);
    }

    function changeTheiaConfig(address _theiaConfig) external onlyGov {
        theiaConfig = _theiaConfig;
        emit LogChangeTheiaConfig(_theiaConfig);
    }

    function changeFeeManager(address _feeManager) external onlyGov {
        feeManager = _feeManager;
        emit LogChangeFeeManager(_feeManager);
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

    function checkParams(
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
    function _transferUnderlying(
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

    function _transferNative(address token) internal returns (uint256) {
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
                _recvAmount = _transferNative(_token);
            } else {
                _recvAmount = _transferUnderlying(_token, _amount);
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
    ) external returns (uint256) {
        uint256 feeRate = _queryLiquidityFeeRate(_theiaToken, _amount);
        uint256 baseFee = IFeeManager(feeManager).getBaseLiquidityFee(
            _theiaToken
        );
        uint256 fee = (baseFee * feeRate) / 1000;
        return fee;
    }

    function _queryLiquidityFeeRate(
        address _theiaToken,
        uint256 _amount
    ) internal returns (uint256) {
        (uint256 _liquidity, uint256 _decimals) = _getLiquidity(_theiaToken);
        uint256 _feeRate = 0;
        if (_decimals > 0) {
            _feeRate = IFeeManager(feeManager).getLiquidityFeeFactor(
                _liquidity,
                _amount
            );
        }
        return _feeRate;
    }

    function _calcAndPay(
        address _feeToken,
        uint256 _toChainID
    ) internal returns (uint256) {
        uint256 feeReadable = IFeeManager(feeManager).getFee(
            cID(),
            _toChainID,
            _feeToken
        );
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

    function getTokenInfo(
        uint256 _chainID,
        string memory _tokenID
    ) internal view returns (TheiaStruct.TokenInfo memory) {
        (
            Structs.TokenConfig memory _fromConfig,
            Structs.TokenConfig memory _toConfig
        ) = ITheiaConfig(theiaConfig).getTokenConfigIfExist(_tokenID, _chainID);
        require(
            _fromConfig.Decimals > 0 && _toConfig.Decimals > 0,
            "Theia:token not support"
        );

        address _token = TheiaUtils.toAddress(_fromConfig.ContractAddress);
        address _token2 = TheiaUtils.toAddress(_toConfig.ContractAddress);

        require(_token2 != address(0), "Theia:recToken empty");
        return
            TheiaStruct.TokenInfo(
                _token,
                _fromConfig.Decimals,
                _token2,
                _toConfig.Decimals
            );
    }

    function theiaCrossEvm(TheiaStruct.CrossAuto memory tc) external payable {
        TheiaStruct.TokenInfo memory t = getTokenInfo(tc.toChainID, tc.tokenID);
        checkParams(t.addr, tc.target, tc.receiver, tc.amount);

        uint256 _recvAmount = _getRevAmount(t.addr, tc.amount);
        require(_recvAmount > 0, "Theia:nothing to cross");

        bytes32 uuid = ITheiaUUIDKeeper(uuidKeeper).genUUIDEvm(
            ITheiaUUIDKeeper.EvmData(
                t.addr,
                msg.sender,
                _recvAmount,
                tc.receiver,
                tc.toChainID
            )
        );

        TheiaStruct.TokenInfo memory f = getTokenInfo(
            tc.toChainID,
            tc.feeTokenID
        );

        uint256 _swapFee = _calcAndPay(f.addr, tc.toChainID);
        require(tc.feeAmount >= _swapFee, "Theia:fee not enough");

        {
            bytes memory _data = genCallData(
                uuid,
                _recvAmount,
                _swapFee,
                tc,
                t,
                f
            );
            c3call(tc.target.toHexString(), tc.toChainID.toString(), _data);
        }

        emit LogTheiaCross(
            t.addr,
            msg.sender,
            uuid,
            _recvAmount,
            cID(),
            tc.toChainID,
            _swapFee,
            f.addr,
            tc.receiver.toHexString()
        );
    }

    function theiaCrossNonEvm(
        TheiaStruct.CrossNonEvm memory tc
    ) external payable {
        require(!tc.target.equal(""), "Theia:to empty");
        require(!tc.receiver.equal(""), "Theia:receiver empty");
        require(tc.amount > 0, "Theia:empty");

        TheiaStruct.TokenInfo memory t = getTokenInfo(tc.toChainID, tc.tokenID);

        require(
            t.decimals > 0 && t.toChainDecimals > 0,
            "Theia:token not support"
        );

        uint256 _recvAmount = _getRevAmount(t.addr, tc.amount);
        require(_recvAmount > 0, "Theia:nothing to cross");

        bytes32 uuid = ITheiaUUIDKeeper(uuidKeeper).genUUIDNonEvm(
            ITheiaUUIDKeeper.NonEvmData(
                t.addr,
                msg.sender,
                _recvAmount,
                tc.toChainID,
                tc.receiver,
                tc.callData
            )
        );

        TheiaStruct.TokenInfo memory f = getTokenInfo(
            tc.toChainID,
            tc.feeTokenID
        );

        uint256 _swapFee = _calcAndPay(f.addr, tc.toChainID);
        require(tc.feeAmount >= _swapFee, "Theia:fee not enough");

        c3call(tc.target, tc.toChainID.toString(), tc.callData, tc.extra);

        emit LogTheiaCross(
            t.addr,
            msg.sender,
            uuid,
            _recvAmount,
            cID(),
            tc.toChainID,
            _swapFee,
            f.addr,
            tc.receiver
        );
    }

    function genCallData(
        bytes32 _uuid,
        uint256 _recvAmount,
        uint256 _swapFee,
        TheiaStruct.CrossAuto memory tc,
        TheiaStruct.TokenInfo memory t,
        TheiaStruct.TokenInfo memory fee
    ) internal view returns (bytes memory) {
        uint256 _toAmount = _recvAmount;

        if (ITheiaERC20(t.addr).decimals() != t.toChainDecimals) {
            _toAmount = convertDecimals(
                _toAmount,
                ITheiaERC20(t.addr).decimals(),
                t.toChainDecimals
            );
            require(_toAmount > 0, "Theia:wrong Decimals");
        }

        uint256 _liquidityFee = tc.feeAmount - _swapFee;
        if (
            _liquidityFee > 0 &&
            ITheiaERC20(fee.addr).decimals() != fee.toChainDecimals
        ) {
            _liquidityFee = convertDecimals(
                _liquidityFee,
                ITheiaERC20(fee.addr).decimals(),
                fee.toChainDecimals
            );
            require(_liquidityFee > 0, "Theia:wrong Decimals");
        }

        return
            abi.encodeWithSelector(
                TheiaStruct.FuncTheiaVaultAuto,
                _uuid,
                t.toChainAddr,
                tc.receiver,
                _toAmount,
                t.toChainDecimals,
                _liquidityFee,
                fee.toChainAddr,
                t.addr
            );
    }

    function theiaVaultAuto(
        bytes32 uuid,
        address token,
        address receiver,
        uint256 amount,
        uint256 tokenDecimals,
        uint256 feePaid,
        address feeToken,
        address fromTokenAddr
    ) external onlyGov returns (bool) {
        require(token != address(0), "Theia:token empty");
        require(uuid.length > 0, "Theia:uuid empty");
        require(receiver != address(0), "Theia:to empty");
        require(amount > 0, "Theia:amount empty");
        require(tokenDecimals > 0, "Theia:tokenDecimals empty");
        require(fromTokenAddr != address(0), "Theia:fromTokenAddr empty");

        (, string memory fromChainID, string memory _sourceTx) = context();

        (uint256 sourceChainID, bool ok) = strToUint(fromChainID);
        require(ok, "Theia:sourceChain invalid");

        require(
            ITheiaERC20(token).decimals() == tokenDecimals,
            "Theia:tokenDecimals dismatch"
        );

        uint256 feeRate = _queryLiquidityFeeRate(token, amount);
        if (feeRate > 0) {
            uint256 baseFee = IFeeManager(feeManager).getBaseLiquidityFee(
                feeToken
            );
            require(baseFee > 0, "Theia:config error");
            uint256 fee = (baseFee * feeRate) / 1000;
            require(feePaid >= fee, "Theia:not cover liquidity fee");
        }

        uint256 recvAmount = _registerAndMint(
            uuid,
            token,
            receiver,
            amount,
            sourceChainID,
            _sourceTx
        );
        return _transferVault(token, receiver, recvAmount);
    }

    function _registerAndMint(
        bytes32 uuid,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string memory sourceTx
    ) internal returns (uint256) {
        ITheiaUUIDKeeper(uuidKeeper).registerUUID(uuid);
        ITheiaERC20(token).mint(to, amount);
        emit LogTheiaVault(
            token,
            to,
            uuid,
            amount,
            fromChainID,
            cID(),
            sourceTx
        );
        return amount;
    }

    function _transferVault(
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

    function _payFee(address feeToken, uint256 fee) internal {
        if (ITheiaERC20(feeToken).underlying() == address(0)) {
            IERC20(feeToken).safeTransferFrom(msg.sender, address(this), fee);
        } else {
            IERC20(ITheiaERC20(feeToken).underlying()).safeTransferFrom(
                msg.sender,
                address(this),
                fee
            );
        }
    }

    function _c3Fallback(
        bytes4 /*_selector*/,
        bytes calldata _data,
        bytes calldata _reason
    ) internal override returns (bool) {
        // decode theiaVaultAuto calldata
        bytes32 _uuid;
        address _receiver;
        uint256 _amount;
        uint256 _recDecimals;
        address _fromToken;
        (_uuid, , _receiver, _amount, _recDecimals, , , _fromToken) = abi
            .decode(
                _data,
                (
                    bytes32,
                    address,
                    address,
                    uint256,
                    uint256,
                    uint256,
                    address,
                    address
                )
            );

        require(
            ITheiaUUIDKeeper(uuidKeeper).isExist(_uuid),
            "Theia:uuid not exists"
        );
        ITheiaUUIDKeeper(uuidKeeper).registerUUID(_uuid);

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

        emit LogTheiaFallback(_uuid, _fromToken, _receiver, _toAmount, _reason);
        return _transferVault(_fromToken, _receiver, _toAmount);
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
