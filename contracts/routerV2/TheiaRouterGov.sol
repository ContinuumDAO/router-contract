// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./TheiaRouterConfig.sol";

contract TheiaRouterGov is
    AccessControl,
    Multicall,
    C3CallerDapp,
    TheiaRouterConfig
{
    bytes4 public FuncSetChainConfig =
        bytes4(keccak256("setChainConfig(uint256,string,string)"));

    bytes4 public FuncSetTokenConfig =
        bytes4(
            keccak256(
                "setTokenConfig(string,uint256,string,uint8,uint256,string,string)"
            )
        );

    bytes4 public FuncSetSwapConfig =
        bytes4(keccak256("setSwapConfig(string,uint256,uint256,uint256)"));

    bytes4 public FuncSetFeeConfig =
        bytes4(
            keccak256(
                "setFeeConfig(string,uint256,uint256,uint256,uint256,uint256,uint256)"
            )
        );

    constructor(
        address _c3callerProxy,
        uint256 _dappID
    ) TheiaRouterConfig(_c3callerProxy, _dappID) {}

    function setChainConfigGov(
        uint256 chainID,
        string memory blockChain,
        string memory routerContract,
        string[] memory toChains,
        string[] memory to
    ) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );

        _setChainConfig(
            chainID,
            Structs.ChainConfig(chainID, blockChain, routerContract)
        );
        bytes memory _data = abi.encodeWithSelector(
            FuncSetChainConfig,
            chainID,
            blockChain,
            routerContract
        );
        c3broadcast(to, toChains, _data);
    }

    function setTokenConfigGov(
        string memory tokenID,
        uint256 chainID,
        string memory tokenAddr,
        uint8 decimals,
        uint256 version,
        string memory routerContract,
        string memory underlying,
        string[] memory toChains,
        string[] memory to
    ) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        _setTokenConfig(
            tokenID,
            chainID,
            Structs.TokenConfig(
                chainID,
                decimals,
                tokenAddr,
                version,
                routerContract,
                underlying
            )
        );

        bytes memory _data = abi.encodeWithSelector(
            FuncSetTokenConfig,
            tokenID,
            chainID,
            decimals,
            tokenAddr,
            version,
            routerContract,
            underlying
        );
        c3broadcast(to, toChains, _data);
    }

    function setSwapConfigGov(
        string memory tokenID,
        uint256 dstChainID,
        uint256 maxSwap, // human-readable amount
        uint256 minSwap, // human-readable amount
        string[] memory toChains,
        string[] memory to
    ) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );

        for (uint256 i = 0; i < toChains.length; i++) {
            bytes memory _data = abi.encodeWithSelector(
                FuncSetSwapConfig,
                tokenID,
                dstChainID,
                maxSwap,
                minSwap
            );
            c3call(to[i], toChains[i], _data);
        }
    }

    function setFeeConfigGov(
        string memory tokenID,
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom, // 1:from 2:to 0:free
        string[] memory toChains,
        string[] memory to
    ) external returns (bool) {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        return
            _setFeeConfig(
                tokenID,
                Structs.FeeConfig(
                    srcChainID,
                    dstChainID,
                    maxFee,
                    minFee,
                    feeRate,
                    payFrom
                )
            );
    }

    function setMPCPubkeyGov(
        string memory addr,
        string memory pubkey,
        string[] memory toChains
    ) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
    }
}
