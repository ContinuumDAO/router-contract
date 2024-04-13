// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

library Structs {
    struct ChainConfig {
        uint256 ChainID;
        string BlockChain;
        string RouterContract;
        string Extra;
    }

    struct TokenConfig {
        uint256 ChainID;
        uint8 Decimals;
        string ContractAddress;
        uint256 ContractVersion;
        string RouterContract;
        string Underlying;
    }

    struct SwapConfig {
        uint256 FromChainID;
        uint256 ToChainID;
        uint256 MaximumSwap;
        uint256 MinimumSwap;
    }

    struct MultichainToken {
        uint256 ChainID;
        string TokenAddress;
    }
}

interface ITheiaConfig {
    function getTokenConfig(
        string memory tokenID,
        uint256 chainID
    ) external view returns (Structs.TokenConfig memory);

    function getTokenConfigIfExist(
        string memory tokenID,
        uint256 toChainID
    )
        external
        view
        returns (Structs.TokenConfig memory, Structs.TokenConfig memory);
}
