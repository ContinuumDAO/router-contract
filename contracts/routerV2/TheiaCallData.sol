// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

contract TheiaCallData {
    function genSwapInAutoCallData(
        address _token,
        uint256 _amount,
        address _receiver,
        bytes32 _swapID
    ) external pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "swapInAuto(bytes32,address,address,uint256)",
                _swapID,
                _token,
                _receiver,
                _amount
            );
    }

    function genCallData4SwapInAndCall(
        address _token,
        uint256 _amount,
        address _receiver,
        bool _native,
        address _dex,
        bytes32 _swapID,
        bytes calldata _data
    ) external pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "swapInAutoAndCall(bytes32,address,bool,address,uint256,address,bytes)",
                _swapID,
                _token,
                _native,
                _receiver,
                _amount,
                _dex,
                _data
            );
    }
}
