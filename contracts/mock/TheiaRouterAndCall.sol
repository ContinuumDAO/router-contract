// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "../routerV2/TheiaUtils.sol";
import "../routerV2/ITheiaUUIDKeeper.sol";
import "../routerV2/ITheiaERC20.sol";
import "../routerV2/FeeManager.sol";
import "../routerV2/ITheiaConfig.sol";
import "../routerV2/TransferHelper.sol";
import "../routerV2/IwNATIVE.sol";
import "../routerV2/IRouter.sol";
import "../routerV2/TheiaStruct.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
//is IRouter, FeeManager
contract TheiaRouterAndCall {
    // using Strings for *;
    // using SafeERC20 for IERC20;
    // using SafeMath for uint256;
    // address public immutable wNATIVE;
    // address public swapIDKeeper;
    // address public theiaConfig;
    // constructor(
    //     address _wNATIVE,
    //     address _swapIDKeeper,
    //     address _theiaConfig,
    //     address _feeToken,
    //     address _gov,
    //     address _c3callerProxy,
    //     uint256 _dappID
    // ) FeeManager(_feeToken, _gov, _c3callerProxy, _dappID) {
    //     wNATIVE = _wNATIVE;
    //     swapIDKeeper = _swapIDKeeper;
    //     theiaConfig = _theiaConfig;
    // }
    // receive() external payable {}
    // fallback() external payable {}
    // modifier chargeDestFee(address _dapp) {
    //     uint256 _prevGasLeft = gasleft();
    //     _;
    // }
    // function cID() public view returns (uint) {
    //     return block.chainid;
    // }
    // function version() public pure returns (uint) {
    //     return 1;
    // }
    // function changeSwapIDKeeper(address _swapIDKeeper) external onlyGov {
    //     swapIDKeeper = _swapIDKeeper;
    // }
    // function setMinter(address token, address _auth) external onlyGov {
    //     return ITheiaERC20(token).setMinter(_auth);
    // }
    // function applyMinter(address token) external onlyGov {
    //     return ITheiaERC20(token).applyMinter();
    // }
    // function revokeMinter(address token, address _auth) external onlyGov {
    //     return ITheiaERC20(token).revokeMinter(_auth);
    // }
    // function checkSwapOut(
    //     address token,
    //     address to,
    //     address receiver,
    //     uint256 amount
    // ) internal pure {
    //     require(token != address(0), "TR:from empty");
    //     require(to != address(0), "TR:to empty");
    //     require(receiver != address(0), "TR:receiver empty");
    //     require(amount > 0, "TR:empty");
    // }
    // // need approve to router first
    // function _swapOutUnderlying(
    //     address token,
    //     uint256 amount
    // ) internal returns (uint256) {
    //     address _underlying = ITheiaERC20(token).underlying();
    //     require(_underlying != address(0), "TR:no underlying");
    //     uint256 old_balance = IERC20(_underlying).balanceOf(token);
    //     IERC20(_underlying).safeTransferFrom(msg.sender, token, amount);
    //     uint256 new_balance = IERC20(_underlying).balanceOf(token);
    //     require(
    //         new_balance >= old_balance && new_balance <= old_balance + amount,
    //         "2"
    //     );
    //     return new_balance - old_balance;
    // }
    // function _swapOutNative(address token) internal returns (uint256) {
    //     require(wNATIVE != address(0), "TR:zero wNATIVE");
    //     require(
    //         ITheiaERC20(token).underlying() == wNATIVE,
    //         "TR:underlying is not wNATIVE"
    //     );
    //     uint256 old_balance = IERC20(wNATIVE).balanceOf(token);
    //     IwNATIVE(wNATIVE).deposit{value: msg.value}();
    //     IERC20(wNATIVE).safeTransfer(token, msg.value);
    //     uint256 new_balance = IERC20(wNATIVE).balanceOf(token);
    //     require(
    //         new_balance >= old_balance &&
    //             new_balance <= old_balance + msg.value,
    //         "1"
    //     );
    //     return new_balance - old_balance;
    // }
    // function _getRevAmount(
    //     address _token,
    //     uint256 _amount
    // ) internal returns (uint256) {
    //     ITheiaERC20 theiaToken = ITheiaERC20(_token);
    //     address _underlying = theiaToken.underlying();
    //     uint256 _recvAmount = 0;
    //     if (_underlying != address(0)) {
    //         if (_underlying == wNATIVE && msg.value >= _amount) {
    //             _recvAmount = _swapOutNative(_token);
    //         } else {
    //             _recvAmount = _swapOutUnderlying(_token, _amount);
    //         }
    //     } else {
    //         theiaToken.burn(msg.sender, _amount);
    //         _recvAmount = _amount;
    //     }
    //     return _recvAmount;
    // }
    // function getLiquidity(
    //     address token
    // ) external view returns (uint256, uint256) {
    //     return _getLiquidity(token);
    // }
    // function _getLiquidity(
    //     address token
    // ) internal view returns (uint256, uint256) {
    //     address underlying = ITheiaERC20(token).underlying();
    //     if (underlying == address(0)) {
    //         return (0, 0);
    //     }
    //     uint256 liquidity = IERC20(underlying).balanceOf(token);
    //     uint256 decimals = IERC20Extended(underlying).decimals();
    //     return (liquidity, decimals);
    // }
    // function queryFee(
    //     address _theiaToken,
    //     uint256 _amount,
    //     address _feeToken,
    //     uint256 _toChainID
    // ) public view returns (uint256) {
    //     uint256 _feeReadable = getFeeConfig(cID(), _toChainID, _feeToken);
    //     uint256 _swapFee = 0;
    //     if (_feeReadable > 0) {
    //         _swapFee = convertDecimals(
    //             _feeReadable,
    //             2,
    //             ITheiaERC20(_feeToken).decimals()
    //         );
    //         (uint256 _liquidity, uint256 _decimals) = _getLiquidity(
    //             _theiaToken
    //         );
    //         // TODO need this?
    //         require(_amount <= _liquidity, "TR: not enough liquidity");
    //         if (_decimals > 0) {
    //             uint256 feeFactor = getFeeFactor(_liquidity, _amount);
    //             _swapFee = (_swapFee * feeFactor) / 1000;
    //         }
    //     }
    //     return _swapFee;
    // }
    // function _calcAndPay(
    //     address _feeToken,
    //     uint256 _toChainID
    // ) internal returns (uint256) {
    //     uint256 feeReadable = getFeeConfig(cID(), _toChainID, _feeToken);
    //     if (feeReadable > 0) {
    //         uint256 _swapFee = convertDecimals(
    //             feeReadable,
    //             2,
    //             ITheiaERC20(_feeToken).decimals()
    //         );
    //         _payFee(_feeToken, _swapFee);
    //         return _swapFee;
    //     }
    //     return 0;
    // }
    // function swapOutAuto(
    //     string memory _tokenID,
    //     uint256 _amount,
    //     address _to,
    //     address _receiver,
    //     address _feeToken,
    //     uint256 _toChainID
    // ) external payable {
    //     (
    //         Structs.TokenConfig memory _fromConfig,
    //         Structs.TokenConfig memory _toConfig
    //     ) = ITheiaConfig(theiaConfig).getTokenConfigIfExist(
    //             _tokenID,
    //             _toChainID
    //         );
    //     require(
    //         _fromConfig.Decimals > 0 && _toConfig.Decimals > 0,
    //         "TR:token not support"
    //     );
    //     address _token = TheiaUtils.toAddress(_fromConfig.ContractAddress);
    //     address _recToken = TheiaUtils.toAddress(_toConfig.ContractAddress);
    //     uint8 _recDecimals = _toConfig.Decimals;
    //     checkSwapOut(_token, _to, _receiver, _amount);
    //     require(_recToken != address(0), "TR:recToken empty");
    //     uint256 _recvAmount = _getRevAmount(_token, _amount);
    //     require(_recvAmount > 0, "TR:nothing to cross");
    //     uint256 _swapFee = _calcAndPay(_feeToken, _toChainID);
    //     bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
    //         _token,
    //         msg.sender,
    //         _recvAmount,
    //         _receiver,
    //         _toChainID
    //     );
    //     uint256 _toAmount = _recvAmount;
    //     if (ITheiaERC20(_token).decimals() != _recDecimals) {
    //         _toAmount = convertDecimals(
    //             _toAmount,
    //             ITheiaERC20(_token).decimals(),
    //             _recDecimals
    //         );
    //         require(_toAmount > 0, "TR:wrong Decimals");
    //     }
    //     bytes memory _data = abi.encodeWithSignature(
    //         "swapInAuto(bytes32,address,address,uint256,uint256,address)",
    //         swapID,
    //         _recToken,
    //         _receiver,
    //         _toAmount,
    //         _recDecimals,
    //         _token
    //     );
    //     c3call(_to.toHexString(), _toChainID.toString(), _data);
    //     emit LogSwapOut(
    //         _token,
    //         msg.sender,
    //         _receiver.toHexString(),
    //         _recvAmount,
    //         cID(),
    //         _toChainID,
    //         _swapFee,
    //         swapID,
    //         _data
    //     );
    // }
    // // TODO add min recvAmount
    // function callAndSwapOut(
    //     address _fromToken,
    //     uint256 _amount,
    //     address _to,
    //     address _toToken,
    //     address _receiver,
    //     address _recToken,
    //     uint8 _recDecimals,
    //     address _feeToken,
    //     uint256 _toChainID,
    //     address _dexAddr,
    //     bytes calldata _data
    // ) external payable {
    //     checkSwapOut(_fromToken, _to, _receiver, _amount);
    //     require(_toToken != address(0), "TR:toToken empty");
    //     require(_dexAddr != address(0), "TR:dexAddr empty");
    //     require(_recToken != address(0), "TR:recToken empty");
    //     ITheiaERC20 toTheiaToken = ITheiaERC20(_toToken);
    //     require(toTheiaToken.underlying() != address(0), "TR:underlying empty");
    //     uint256 _swapFee = _calcAndPay(_feeToken, _toChainID);
    //     uint256 _old_amount = _balanceOf(toTheiaToken.underlying());
    //     bool success;
    //     bytes memory result;
    //     ITheiaERC20 theiaToken = ITheiaERC20(_fromToken);
    //     address _underlying = theiaToken.underlying();
    //     if (
    //         _underlying != address(0) &&
    //         IERC20(_fromToken).balanceOf(msg.sender) < _amount
    //     ) {
    //         if (_underlying == wNATIVE) {
    //             require(msg.value >= _amount, "TR:balance not enough");
    //             (success, result) = _dexAddr.call{value: msg.value}(_data);
    //         } else {
    //             require(
    //                 IERC20(_underlying).balanceOf(msg.sender) >= _amount,
    //                 "TR:balance not enough"
    //             );
    //             IERC20(_underlying).safeTransferFrom(
    //                 msg.sender,
    //                 address(this),
    //                 _amount
    //             );
    //             IERC20(_underlying).approve(_dexAddr, _amount);
    //             (success, result) = _dexAddr.call(_data);
    //         }
    //     } else {
    //         require(
    //             IERC20(_fromToken).balanceOf(msg.sender) >= _amount,
    //             "TR:balance not enough"
    //         );
    //         ITheiaERC20(_fromToken).burn(msg.sender, _amount);
    //         ITheiaERC20(_fromToken).mint(address(this), _amount);
    //         IERC20(_fromToken).approve(_dexAddr, _amount);
    //         (success, result) = _dexAddr.call(_data);
    //     }
    //     uint256 amount = _balanceOf(toTheiaToken.underlying());
    //     if (success) {
    //         require(amount - _old_amount > 0, "TR:nothing received");
    //     }
    //     uint256 _toAmount = amount - _old_amount;
    //     require(_toAmount > 0, "TR:nothing to cross");
    //     IERC20(toTheiaToken.underlying()).safeTransferFrom(
    //         address(this),
    //         _toToken,
    //         _toAmount
    //     );
    //     if (toTheiaToken.decimals() != _recDecimals) {
    //         _toAmount = convertDecimals(
    //             _toAmount,
    //             toTheiaToken.decimals(),
    //             _recDecimals
    //         );
    //         require(_toAmount > 0, "TR:wrong Decimals");
    //     }
    //     bytes32 _swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
    //         _fromToken,
    //         msg.sender,
    //         _amount,
    //         _receiver,
    //         _toChainID
    //     );
    //     bytes memory _call_data = abi.encodeWithSignature(
    //         "swapInAuto(bytes32,address,address,uint256,uint256,address)",
    //         _swapID,
    //         _recToken,
    //         _receiver,
    //         _toAmount,
    //         _recDecimals,
    //         _toToken
    //     );
    //     c3call(_to.toHexString(), _toChainID.toString(), _call_data);
    //     emit LogSwapOut(
    //         _toToken,
    //         msg.sender,
    //         _receiver.toHexString(),
    //         amount,
    //         cID(),
    //         _toChainID,
    //         _swapFee,
    //         _swapID,
    //         _call_data
    //     );
    // }
    // // TODO add min recvAmount
    // function swapOutAndCall(
    //     address _token,
    //     uint256 _amount,
    //     address _to,
    //     address _receiver,
    //     address _recToken,
    //     uint8 _recDecimals,
    //     address _feeToken,
    //     uint256 _toChainID,
    //     bool _native,
    //     address _dex,
    //     bytes calldata _data
    // ) external payable {
    //     checkSwapOut(_token, _to, _receiver, _amount);
    //     require(_dex != address(0), "TR:dex empty");
    //     require(_data.length > 0, "TR:data empty");
    //     require(_recToken != address(0), "TR:recToken empty");
    //     require(_recDecimals > 0, "TR:recDecimals empty");
    //     uint256 _swapFee = _calcAndPay(_feeToken, _toChainID);
    //     uint256 _recvAmount = _getRevAmount(_token, _amount);
    //     uint256 _toAmount = _recvAmount;
    //     require(_toAmount > 0, "TR:nothing to cross");
    //     ITheiaERC20 toTheiaToken = ITheiaERC20(_token);
    //     if (toTheiaToken.decimals() != _recDecimals) {
    //         _toAmount = convertDecimals(
    //             _toAmount,
    //             toTheiaToken.decimals(),
    //             _recDecimals
    //         );
    //         require(_toAmount > 0, "TR: wrong Decimals");
    //     }
    //     bytes32 _swapID = ISwapIDKeeper(swapIDKeeper).registerSwapoutEvm(
    //         _token,
    //         msg.sender,
    //         _amount,
    //         _receiver,
    //         _toChainID
    //     );
    //     bytes memory data = abi.encodeWithSignature(
    //         "swapInAutoAndCall(bytes32,address,bool,address,uint256,uint256,address,address,bytes)",
    //         _swapID,
    //         _recToken,
    //         _native,
    //         _receiver,
    //         _toAmount,
    //         _recDecimals,
    //         _token,
    //         _dex,
    //         _data
    //     );
    //     c3call(_to.toHexString(), _toChainID.toString(), data);
    //     emit LogSwapOut(
    //         _token,
    //         msg.sender,
    //         _receiver.toHexString(),
    //         _amount,
    //         cID(),
    //         _toChainID,
    //         _swapFee,
    //         _swapID,
    //         data
    //     );
    // }
    // function _swapIn(
    //     bytes32 swapID,
    //     address token,
    //     address to,
    //     uint256 amount,
    //     uint256 fromChainID,
    //     string memory sourceTx
    // ) internal returns (uint256) {
    //     ISwapIDKeeper(swapIDKeeper).registerSwapin(swapID);
    //     ITheiaERC20(token).mint(to, amount);
    //     emit LogSwapIn(token, to, swapID, amount, fromChainID, cID(), sourceTx);
    //     return amount;
    // }
    // function swapInAuto(
    //     bytes32 swapID,
    //     address token,
    //     address to,
    //     uint256 amount,
    //     uint256 tokenDecimals,
    //     address fromTokenAddr
    // ) external onlyGov returns (bool) {
    //     require(token != address(0), "TR:token empty");
    //     require(swapID.length > 0, "TR:swapID empty");
    //     require(to != address(0), "TR:to empty");
    //     require(amount > 0, "TR:amount empty");
    //     require(tokenDecimals > 0, "TR:tokenDecimals empty");
    //     require(fromTokenAddr != address(0), "TR:fromTokenAddr empty");
    //     (, string memory fromChainID, string memory _sourceTx, ) = context();
    //     (uint256 sourceChainID, bool ok) = strToUint(fromChainID);
    //     require(ok, "TR:sourceChain invalid");
    //     require(
    //         ITheiaERC20(token).decimals() == tokenDecimals,
    //         "TR:tokenDecimals dismatch"
    //     );
    //     uint256 recvAmount = _swapIn(
    //         swapID,
    //         token,
    //         to,
    //         amount,
    //         sourceChainID,
    //         _sourceTx
    //     );
    //     return _swapAuto(token, to, recvAmount);
    // }
    // function _swapAuto(
    //     address token,
    //     address to,
    //     uint256 recvAmount
    // ) internal returns (bool) {
    //     ITheiaERC20 theiaToken = ITheiaERC20(token);
    //     address _underlying = theiaToken.underlying();
    //     if (_underlying != address(0)) {
    //         // TODO is it allowed to just mint veToken if underlying is insufficient?
    //         require(
    //             IERC20(_underlying).balanceOf(token) >= recvAmount,
    //             "TR:insufficient balance"
    //         );
    //         if (_underlying == wNATIVE) {
    //             theiaToken.withdrawVault(to, recvAmount, address(this));
    //             IwNATIVE(wNATIVE).withdraw(recvAmount);
    //             TransferHelper.safeTransferNative(to, recvAmount);
    //         } else {
    //             theiaToken.withdrawVault(to, recvAmount, to);
    //         }
    //     }
    //     return true;
    // }
    // function swapInAutoAndCall(
    //     bytes32 swapID,
    //     address token,
    //     bool native,
    //     address to,
    //     uint256 amount,
    //     uint256 tokenDecimals,
    //     address fromTokenAddr, // use string?
    //     address dex,
    //     bytes memory data
    // ) external onlyGov returns (bool) {
    //     require(token != address(0), "TR:token empty");
    //     require(swapID.length > 0, "TR:swapID empty");
    //     require(to != address(0), "TR:to empty");
    //     require(amount > 0, "TR:amount empty");
    //     require(tokenDecimals > 0, "TR:tokenDecimals empty");
    //     require(fromTokenAddr != address(0), "TR:fromTokenAddr empty");
    //     (, string memory fromChainID, string memory _sourceTx, ) = context();
    //     (uint256 sourceChainID, bool ok) = strToUint(fromChainID);
    //     require(ok, "TR:sourceChain is invalid");
    //     ITheiaERC20 theiaToken = ITheiaERC20(token);
    //     require(
    //         theiaToken.decimals() == tokenDecimals,
    //         "TR:tokenDecimals dismatch"
    //     );
    //     uint256 recvAmount = _swapIn(
    //         swapID,
    //         token,
    //         to,
    //         amount,
    //         sourceChainID,
    //         _sourceTx
    //     );
    //     address _underlying = theiaToken.underlying();
    //     // uint256 _old_amount = _balanceOf(_underlying);
    //     bool success;
    //     bytes memory result;
    //     if (
    //         _underlying != address(0) &&
    //         IERC20(_underlying).balanceOf(token) >= recvAmount
    //     ) {
    //         theiaToken.withdrawVault(to, recvAmount, address(this));
    //         if (_underlying == wNATIVE && native) {
    //             IwNATIVE(wNATIVE).withdraw(recvAmount);
    //             (success, result) = dex.call{value: recvAmount}(data);
    //         } else {
    //             IERC20(_underlying).safeApprove(dex, recvAmount);
    //             (success, result) = dex.call(data);
    //         }
    //     } else {
    //         theiaToken.burn(to, recvAmount);
    //         theiaToken.mint(address(this), recvAmount);
    //         IERC20(token).safeApprove(dex, recvAmount);
    //         (success, result) = dex.call(data);
    //     }
    //     // TODO should move asset to user address
    //     // uint256 _amount = _balanceOf(_underlying);
    //     return success;
    // }
    // function _c3Fallback(
    //     bytes4 _selector,
    //     bytes calldata _data,
    //     bytes calldata _reason
    // ) internal override returns (bool) {
    //     bytes32 _swapID;
    //     address _receiver;
    //     uint256 _amount;
    //     uint256 _recDecimals;
    //     address _fromToken;
    //     if (_selector == TheiaStruct.FuncSwapInAutoAndCall) {
    //         (
    //             _swapID,
    //             ,
    //             ,
    //             _receiver,
    //             _amount,
    //             _recDecimals,
    //             _fromToken,
    //             ,
    //         ) = abi.decode(
    //             _data,
    //             (
    //                 bytes32,
    //                 address,
    //                 bool,
    //                 address,
    //                 uint256,
    //                 uint256,
    //                 address,
    //                 address,
    //                 bytes
    //             )
    //         );
    //     } else {
    //         (_swapID, , _receiver, _amount, _recDecimals, _fromToken) = abi
    //             .decode(
    //                 _data,
    //                 (bytes32, address, address, uint256, uint256, address)
    //             );
    //     }
    //     require(
    //         ISwapIDKeeper(swapIDKeeper).isSwapoutIDExist(_swapID),
    //         "TR:swapId not exists"
    //     );
    //     ISwapIDKeeper(swapIDKeeper).registerSwapin(_swapID);
    //     uint256 _toAmount = _amount;
    //     if (ITheiaERC20(_fromToken).decimals() != _recDecimals) {
    //         _toAmount = convertDecimals(
    //             _amount,
    //             _recDecimals,
    //             ITheiaERC20(_fromToken).decimals()
    //         );
    //     }
    //     require(_toAmount > 0, "TR:recAmount convert err");
    //     ITheiaERC20(_fromToken).mint(_receiver, _toAmount);
    //     emit LogSwapFallback(
    //         _swapID,
    //         _fromToken,
    //         _receiver,
    //         _toAmount,
    //         _selector,
    //         _data,
    //         _reason
    //     );
    //     return _swapAuto(_fromToken, _receiver, _toAmount);
    // }
    // function depositNative(
    //     address token,
    //     address to
    // ) external payable returns (uint256) {
    //     require(wNATIVE != address(0), "TR:zero wNATIVE");
    //     require(
    //         ITheiaERC20(token).underlying() == wNATIVE,
    //         "TR:underlying is not wNATIVE"
    //     );
    //     IwNATIVE(wNATIVE).deposit{value: msg.value}();
    //     assert(IwNATIVE(wNATIVE).transfer(token, msg.value));
    //     ITheiaERC20(token).depositVault(msg.value, to);
    //     return msg.value;
    // }
    // function withdrawNative(
    //     address token,
    //     uint256 amount,
    //     address to
    // ) external returns (uint256) {
    //     require(wNATIVE != address(0), "TR:zero wNATIVE");
    //     require(
    //         ITheiaERC20(token).underlying() == wNATIVE,
    //         "TR:underlying is not wNATIVE"
    //     );
    //     uint256 old_balance = IERC20(wNATIVE).balanceOf(address(this));
    //     ITheiaERC20(token).withdrawVault(msg.sender, amount, address(this));
    //     uint256 new_balance = IERC20(wNATIVE).balanceOf(address(this));
    //     assert(new_balance == old_balance + amount);
    //     IwNATIVE(wNATIVE).withdraw(amount);
    //     TransferHelper.safeTransferNative(to, amount);
    //     return amount;
    // }
    // //  extracts gov fee from bridge fees
    // function withdrawFee(address[] calldata tokens) external onlyGov {
    //     address _gov = gov();
    //     for (uint index = 0; index < tokens.length; index++) {
    //         address _token = tokens[index];
    //         uint256 amount = IERC20(_token).balanceOf(address(this));
    //         if (amount > 0) {
    //             ITheiaERC20(_token).withdrawVault(address(this), amount, _gov);
    //         }
    //     }
    // }
    // function strToUint(
    //     string memory _str
    // ) public pure returns (uint256 res, bool err) {
    //     if (bytes(_str).length == 0) {
    //         return (0, true);
    //     }
    //     for (uint256 i = 0; i < bytes(_str).length; i++) {
    //         if (
    //             (uint8(bytes(_str)[i]) - 48) < 0 ||
    //             (uint8(bytes(_str)[i]) - 48) > 9
    //         ) {
    //             return (0, false);
    //         }
    //         res +=
    //             (uint8(bytes(_str)[i]) - 48) *
    //             10 ** (bytes(_str).length - i - 1);
    //     }
    //     return (res, true);
    // }
    // function convertDecimals(
    //     uint256 amount,
    //     uint256 from,
    //     uint256 to
    // ) public pure returns (uint256) {
    //     if (from == to) return amount;
    //     if (from > to) {
    //         //uint256 res = from.sub(to);
    //         uint256 res = from - to;
    //         (bool ok, uint256 rtn) = amount.tryDiv(10 ** res);
    //         if (ok) return rtn;
    //         return 0;
    //     } else {
    //         //uint256 res = to.sub(from);
    //         uint256 res = to - from;
    //         (bool ok, uint256 rtn) = amount.tryMul(10 ** res);
    //         if (ok) return rtn;
    //         return 0;
    //     }
    // }
    // function _balanceOf(address receiveToken) internal view returns (uint256) {
    //     return IERC20(receiveToken).balanceOf(address(this));
    // }
}
