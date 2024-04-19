// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

library TheiaStruct {
    bytes4 public constant FuncSwapInAuto =
        bytes4(
            keccak256(
                "swapInAuto(bytes32,address,address,uint256,uint256,address)"
            )
        );
    bytes4 public constant FuncSwapInAutoAndCall =
        bytes4(
            keccak256(
                "swapInAutoAndCall(bytes32,address,bool,address,uint256,uint256,address,address,bytes)"
            )
        );
}
