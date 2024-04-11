// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "../protocol/C3CallerDapp.sol";
import "./ITheiaConfig.sol";

contract TheiaRouterConfig is
    AccessControl,
    Multicall,
    C3CallerDapp,
    ITheiaConfig
{
    uint256 public constant CONFIG_VERSION = 1;
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    // chain configuration
    uint256[] private _allChainIDs;
    mapping(uint256 => bool) private _allChainIDsMap; // key is chainID
    mapping(uint256 => Structs.ChainConfig) private _chainConfig; // key is chainID

    // token configuration
    string[] private _allTokenIDs;
    mapping(string => bool) private _allTokenIDsMap; // key is tokenID
    mapping(string => Structs.MultichainToken[]) private _allMultichainTokens; // key is tokenID
    mapping(string => Structs.SwapConfig[]) private _allSwapConfigs; // key is tokenID
    mapping(string => Structs.FeeConfig[]) private _allFeeConfigs; // key is tokenID

    // relationship configuration
    mapping(string => mapping(uint256 => Structs.TokenConfig))
        private _tokenConfig; // key is tokenID,chainID
    mapping(string => mapping(uint256 => string))
        private _allMultichainTokensMap; // key is tokenID,chainID

    mapping(string => mapping(uint256 => mapping(uint256 => Structs.SwapConfig)))
        private _swapConfig; // key is tokenID,srcChainID,dstChainID
    mapping(string => mapping(uint256 => mapping(uint256 => Structs.FeeConfig)))
        private _feeConfig; // key is tokenID,srcChainID,dstChainID

    mapping(uint256 => mapping(string => string)) private _tokenIDMap; // key is chainID,tokenAddress

    // mpc configuration
    mapping(string => string) private _mpcPubkey; // key is mpc address

    constructor(
        address _c3callerProxy,
        uint256 _dappID
    ) C3CallerDapp(_c3callerProxy, _dappID) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONFIG_ROLE, msg.sender);
    }

    function getAllChainIDs() external view returns (uint256[] memory) {
        return _allChainIDs;
    }

    function getAllChainIDLength() external view returns (uint256) {
        return _allChainIDs.length;
    }

    function getChainIDByIndex(uint256 index) external view returns (uint256) {
        return _allChainIDs[index];
    }

    function isChainIDExist(uint256 chainID) public view returns (bool) {
        return _allChainIDsMap[chainID];
    }

    function getAllTokenIDs() external view returns (string[] memory result) {
        return _allTokenIDs;
    }

    function getAllTokenIDLength() external view returns (uint256) {
        return _allTokenIDs.length;
    }

    function getTokenIDByIndex(
        uint256 index
    ) external view returns (string memory) {
        return _allTokenIDs[index];
    }

    function isTokenIDExist(string memory tokenID) public view returns (bool) {
        return _allTokenIDsMap[tokenID];
    }

    function getAllMultichainTokens(
        string memory tokenID
    ) external view returns (Structs.MultichainToken[] memory) {
        return _allMultichainTokens[tokenID];
    }

    function getMultichainToken(
        string memory tokenID,
        uint256 chainID
    ) external view returns (string memory) {
        return _allMultichainTokensMap[tokenID][chainID];
    }

    function getAllMultichainTokenConfig(
        string memory tokenID
    ) external view returns (Structs.TokenConfig[] memory) {
        Structs.MultichainToken[] memory _mcTokens = _allMultichainTokens[
            tokenID
        ];
        uint256 count = _mcTokens.length;
        Structs.TokenConfig[] memory result = new Structs.TokenConfig[](count);
        mapping(uint256 => Structs.TokenConfig) storage _configs = _tokenConfig[
            tokenID
        ];
        Structs.TokenConfig memory c;
        for (uint256 i = 0; i < count; i++) {
            uint256 chainID = _mcTokens[i].ChainID;
            c = _configs[chainID];
            if (
                bytes(c.RouterContract).length == 0 &&
                bytes(c.ContractAddress).length > 0
            ) {
                c.RouterContract = _chainConfig[chainID].RouterContract;
            }
            result[i] = Structs.TokenConfig(
                chainID,
                c.Decimals,
                c.ContractAddress,
                c.ContractVersion,
                c.RouterContract,
                c.Underlying
            );
        }
        return result;
    }

    function getTokenID(
        uint256 chainID,
        string memory tokenAddress
    ) external view returns (string memory) {
        return _tokenIDMap[chainID][tokenAddress];
    }

    function getChainConfig(
        uint256 chainID
    ) external view returns (Structs.ChainConfig memory) {
        return _chainConfig[chainID];
    }

    function getAllChainConfig()
        external
        view
        returns (Structs.ChainConfig[] memory)
    {
        uint256 count = _allChainIDs.length;
        Structs.ChainConfig[] memory result = new Structs.ChainConfig[](count);
        Structs.ChainConfig memory c;
        for (uint256 i = 0; i < count; i++) {
            uint256 chainID = _allChainIDs[i];
            c = _chainConfig[chainID];
            result[i] = Structs.ChainConfig(
                chainID,
                c.BlockChain,
                c.RouterContract
            );
        }
        return result;
    }

    function getOriginalTokenConfig(
        string memory tokenID,
        uint256 chainID
    ) external view returns (Structs.TokenConfig memory) {
        return _tokenConfig[tokenID][chainID];
    }

    function getTokenConfig(
        string memory tokenID,
        uint256 chainID
    ) external view returns (Structs.TokenConfig memory) {
        Structs.TokenConfig memory c = _tokenConfig[tokenID][chainID];
        if (bytes(c.RouterContract).length == 0) {
            c.RouterContract = _chainConfig[chainID].RouterContract;
        }
        return c;
    }

    function getTokenConfigIfExist(
        string memory tokenID,
        uint256 toChainID
    )
        external
        view
        returns (Structs.TokenConfig memory, Structs.TokenConfig memory)
    {
        Structs.TokenConfig memory c = _tokenConfig[tokenID][block.chainid];
        require(c.Decimals > 0, "Token not exist on fromChain");
        Structs.TokenConfig memory tc = _tokenConfig[tokenID][toChainID];
        require(tc.Decimals > 0, "TokenAddr not exist on toChain");
        return (c, tc);
    }

    function getSwapConfig(
        string memory tokenID,
        uint256 srcChainID,
        uint256 dstChainID
    ) external view returns (Structs.SwapConfig memory) {
        return _swapConfig[tokenID][srcChainID][dstChainID];
    }

    function getFeeConfig(
        string memory tokenID,
        uint256 srcChainID,
        uint256 dstChainID
    ) external view returns (Structs.FeeConfig memory) {
        return _feeConfig[tokenID][srcChainID][dstChainID];
    }

    function getAllSwapConfigs(
        string memory tokenID
    ) external view returns (Structs.SwapConfig[] memory) {
        return _allSwapConfigs[tokenID];
    }

    function getSwapConfigsCount(
        string memory tokenID
    ) external view returns (uint256) {
        return _allSwapConfigs[tokenID].length;
    }

    function getSwapConfigAtIndex(
        string memory tokenID,
        uint256 index
    ) external view returns (Structs.SwapConfig memory) {
        return _allSwapConfigs[tokenID][index];
    }

    function getSwapConfigAtIndexRange(
        string memory tokenID,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (Structs.SwapConfig[] memory) {
        Structs.SwapConfig[] storage _configs = _allSwapConfigs[tokenID];
        if (endIndex > _configs.length) {
            endIndex = _configs.length;
        }
        uint256 count = endIndex - startIndex;
        Structs.SwapConfig[] memory result = new Structs.SwapConfig[](count);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = _configs[i];
        }
        return result;
    }

    function getAllFeeConfigs(
        string memory tokenID
    ) external view returns (Structs.FeeConfig[] memory) {
        return _allFeeConfigs[tokenID];
    }

    function getFeeConfigsCount(
        string memory tokenID
    ) external view returns (uint256) {
        return _allFeeConfigs[tokenID].length;
    }

    function getFeeConfigAtIndex(
        string memory tokenID,
        uint256 index
    ) external view returns (Structs.FeeConfig memory) {
        return _allFeeConfigs[tokenID][index];
    }

    function getFeeConfigAtIndexRange(
        string memory tokenID,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (Structs.FeeConfig[] memory) {
        Structs.FeeConfig[] storage _configs = _allFeeConfigs[tokenID];
        if (endIndex > _configs.length) {
            endIndex = _configs.length;
        }
        uint256 count = endIndex - startIndex;
        Structs.FeeConfig[] memory result = new Structs.FeeConfig[](count);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = _configs[i];
        }
        return result;
    }

    function getMPCPubkey(
        string memory mpcAddress
    ) external view returns (string memory) {
        return _mpcPubkey[mpcAddress];
    }

    function setChainConfig(
        uint256 chainID,
        string memory blockChain,
        string memory routerContract
    ) external returns (bool) {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        return
            _setChainConfig(
                chainID,
                Structs.ChainConfig(chainID, blockChain, routerContract)
            );
    }

    function setTokenConfig(
        string memory tokenID,
        uint256 chainID,
        string memory tokenAddr,
        uint8 decimals,
        uint256 version,
        string memory routerContract,
        string memory underlying
    ) external returns (bool) {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        return
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
    }

    function setSwapAndFeeConfig(
        string memory tokenID,
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxSwap,
        uint256 minSwap,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom // 1:from 2:to 0:free
    ) external returns (bool) {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        return
            _setSwapConfig(
                tokenID,
                Structs.SwapConfig(srcChainID, dstChainID, maxSwap, minSwap)
            ) &&
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

    function setSwapConfig(
        string memory tokenID,
        uint256 dstChainID,
        uint256 maxSwap,
        uint256 minSwap
    ) external returns (bool) {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        return
            _setSwapConfig(
                tokenID,
                Structs.SwapConfig(block.chainid, dstChainID, maxSwap, minSwap)
            );
    }

    function setSwapConfigs(
        string memory tokenID,
        Structs.SwapConfig[] calldata configs
    ) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        for (uint256 i = 0; i < configs.length; i++) {
            _setSwapConfig(tokenID, configs[i]);
        }
    }

    function setFeeConfig(
        string memory tokenID,
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom // 1:from 2:to 0:free
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

    function setFeeConfigs(
        string memory tokenID,
        Structs.FeeConfig[] calldata configs
    ) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        for (uint256 i = 0; i < configs.length; i++) {
            _setFeeConfig(tokenID, configs[i]);
        }
    }

    function setMPCPubkey(string memory addr, string memory pubkey) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender),
            "RouterConfig: no config role"
        );
        _mpcPubkey[addr] = pubkey;
    }

    // function addChainID(uint256 chainID) external returns (bool) {
    //     require(
    //         hasRole(CONFIG_ROLE, msg.sender),
    //         "RouterConfig: no config role"
    //     );
    //     require(!isChainIDExist(chainID));
    //     _allChainIDs.push(chainID);
    //     _allChainIDsMap[chainID] = true;
    //     return true;
    // }

    // function addTokenID(string memory tokenID) external returns (bool) {
    //     require(
    //         hasRole(CONFIG_ROLE, msg.sender),
    //         "RouterConfig: no config role"
    //     );
    //     require(!isTokenIDExist(tokenID));
    //     _allTokenIDs.push(tokenID);
    //     _allTokenIDsMap[tokenID] = true;
    //     return true;
    // }

    // function setMultichainToken(
    //     string memory tokenID,
    //     uint256 chainID,
    //     string memory token
    // ) public {
    //     require(
    //         hasRole(CONFIG_ROLE, msg.sender),
    //         "RouterConfig: no config role"
    //     );
    //     _setMultichainToken(tokenID, chainID, token);
    // }

    function _c3Fallback(
        bytes4 _selector,
        bytes calldata _data,
        bytes calldata _reason
    ) internal override returns (bool) {
        return true;
    }

    function _isStringEqual(
        string memory s1,
        string memory s2
    ) internal pure returns (bool) {
        return
            bytes(s1).length == bytes(s2).length &&
            keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

    function _setChainConfig(
        uint256 chainID,
        Structs.ChainConfig memory config
    ) internal returns (bool) {
        require(chainID > 0);
        _chainConfig[chainID] = config;
        _chainConfig[chainID].ChainID = chainID;
        if (!isChainIDExist(chainID)) {
            _allChainIDs.push(chainID);
            _allChainIDsMap[chainID] = true;
        }
        return true;
    }

    function _setTokenConfig(
        string memory tokenID,
        uint256 chainID,
        Structs.TokenConfig memory config
    ) internal returns (bool) {
        require(chainID > 0 && bytes(tokenID).length > 0);
        config.ChainID = chainID;
        _tokenConfig[tokenID][chainID] = config;
        if (!isTokenIDExist(tokenID)) {
            _allTokenIDs.push(tokenID);
            _allTokenIDsMap[tokenID] = true;
        }
        _setMultichainToken(tokenID, chainID, config.ContractAddress);
        return true;
    }

    function _setSwapConfig(
        string memory tokenID,
        Structs.SwapConfig memory config
    ) internal returns (bool) {
        require(bytes(tokenID).length > 0);

        uint256 srcChainID = config.FromChainID;
        uint256 dstChainID = config.ToChainID;
        _swapConfig[tokenID][srcChainID][dstChainID] = config;

        Structs.SwapConfig[] storage _configs = _allSwapConfigs[tokenID];
        uint256 length = _configs.length;
        Structs.SwapConfig memory _config;
        for (uint256 i = 0; i < length; ++i) {
            _config = _configs[i];
            if (
                _config.FromChainID == srcChainID &&
                _config.ToChainID == dstChainID
            ) {
                _configs[i] = config;
                return true;
            }
        }
        _configs.push(config);
        return true;
    }

    function _setFeeConfig(
        string memory tokenID,
        Structs.FeeConfig memory config
    ) internal returns (bool) {
        require(bytes(tokenID).length > 0);

        uint256 srcChainID = config.FromChainID;
        uint256 dstChainID = config.ToChainID;
        _feeConfig[tokenID][srcChainID][dstChainID] = config;

        Structs.FeeConfig[] storage _configs = _allFeeConfigs[tokenID];
        uint256 length = _configs.length;
        Structs.FeeConfig memory _config;
        for (uint256 i = 0; i < length; ++i) {
            _config = _configs[i];
            if (
                _config.FromChainID == srcChainID &&
                _config.ToChainID == dstChainID
            ) {
                _configs[i] = config;
                return true;
            }
        }
        _configs.push(config);
        return true;
    }

    function _setMultichainToken(
        string memory tokenID,
        uint256 chainID,
        string memory token
    ) internal {
        require(chainID > 0 && bytes(tokenID).length > 0);

        _tokenIDMap[chainID][token] = tokenID;
        _allMultichainTokensMap[tokenID][chainID] = token;

        Structs.MultichainToken[] storage _mcTokens = _allMultichainTokens[
            tokenID
        ];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].ChainID == chainID) {
                string memory oldToken = _mcTokens[i].TokenAddress;
                if (!_isStringEqual(token, oldToken)) {
                    _mcTokens[i].TokenAddress = token;
                    _tokenIDMap[chainID][oldToken] = "";
                }
                return;
            }
        }
        _mcTokens.push(Structs.MultichainToken(chainID, token));
    }
}
