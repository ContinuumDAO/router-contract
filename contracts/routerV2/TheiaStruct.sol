// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

library TheiaStruct {
    bytes4 public constant FuncTheiaVaultAuto =
        bytes4(
            keccak256(
                "theiaVaultAuto(bytes32,address,address,uint256,uint256,uint256,address,address)"
            )
        );

    struct CrossAuto {
        address target;
        address receiver;
        uint256 amount;
        uint256 feeAmount;
        uint256 toChainID;
        string tokenID;
        string feeTokenID;
    }

    struct CrossNonEvm {
        uint256 amount;
        uint256 feeAmount;
        uint256 toChainID;
        string target;
        string receiver;
        string tokenID;
        string feeTokenID;
        bytes callData;
        bytes extra;
    }

    struct TokenInfo {
        address addr;
        uint8 decimals;
        address toChainAddr;
        uint8 toChainDecimals;
    }
}
