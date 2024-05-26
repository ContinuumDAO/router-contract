// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

// for test
contract TheiaCallData {
    function genSwapInAutoCallData(
        address _token,
        uint256 _amount,
        address _receiver,
        bytes32 _swapID,
        uint256 _recDecimals,
        address _fromToken
    ) external pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "swapInAuto(bytes32,address,address,uint256,uint256,address)",
                _swapID,
                _token,
                _receiver,
                _amount,
                _recDecimals,
                _fromToken
            );
    }

    function genCallData4SwapInAndCall(
        address _token,
        uint256 _amount,
        address _receiver,
        bool _native,
        address _dex,
        bytes32 _swapID,
        uint8 _recDecimals,
        address _fromToken,
        bytes calldata _data
    ) external pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "swapInAutoAndCall(bytes32,address,bool,address,uint256,uint256,address,address,bytes)",
                _swapID,
                _token,
                _native,
                _receiver,
                _amount,
                _recDecimals,
                _fromToken,
                _dex,
                _data
            );
    }
}
