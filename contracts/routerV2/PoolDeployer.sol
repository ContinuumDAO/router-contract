// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IPoolDeployer.sol";
import "./ITheiaERC20.sol";
import "./GovernDapp.sol";
import {TheiaERC20} from "./TheiaERC20.sol";

contract PoolDeployer is IPoolDeployer, GovernDapp {
    using Strings for *;
    using SafeERC20 for IERC20;

    address public immutable wNATIVE;

    string[] public poolTokenSymbols;

    constructor(
        address _txSender,
        address _c3callerProxy,
        uint256 _dappID,
        address _gov,
        address _wNATIVE
    ) GovernDapp(_gov, _c3callerProxy, _txSender, _dappID) {
        wNATIVE = _wNATIVE;
    }

    mapping(address => bool) public isOperator;
    address[] public operators;

    mapping(string => mapping(string => string)) public symbolToToken; // On veTHIEA chain: liquidity symbol => toChainId => token address
    mapping(string => mapping(string => string)) public tokenToSymbol; // On veTHIEA chain: token address => tochainId => liquidity symbol

    event LogFallback(bytes4 selector, bytes data, bytes reason);
    event LogNewTheiaFallBack(
            string chainIdStr,
            string name,
            string symbol,
            string underlyingStr
    );

    bytes4 public FuncDeployTheia =
        bytes4(
            keccak256(
                "deployTheia(string,string,string,uint8,string,bytes32,string)"
            )
        );

     modifier onlyAuth() {
        require(
            isOperator[msg.sender] || isCaller(msg.sender),
            "Theia StagingVault: AUTH FORBIDDEN"
        );
        _;
    }

    function newTheiaTokenEVM(
        string memory _name,
        string memory _symbol,
        uint8[] memory _decimals,
        address[] memory _underlying,
        uint256[] memory _chainIds,
        bytes32 _salt,
        address[] memory _router
    ) onlyGov external {
        address theia;
        string memory fromTargetStr = cID().toHexString();
        string memory funcCall = "deployTheia(string,string,string,uint8,string,bytes32,string)";
        string memory targetStr;
        string memory toChainIdStr;

        uint256 len = _chainIds.length;

        for (uint256 i=0; i< len; i++) {
            
            if(_chainIds[i] == cID()) {
                theia = address(new TheiaERC20{salt: _salt}(
                    _name,
                    _symbol,
                    _decimals[i],
                    _underlying[i],
                    _router[i]
                ));
            } else {
                toChainIdStr = cID().toHexString();
                bytes memory callData = abi.encodeWithSignature(
                    funcCall,
                    fromTargetStr,
                    _name,
                    _symbol,
                    _decimals[i],
                    _underlying[i].toHexString(),
                    _router[i].toHexString()
                );

                c3call(targetStr, toChainIdStr, callData);
            }
        }

    }

    function deployTheia(
        string memory _fromChainIdStr,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        string memory _underlyingStr,
        bytes32 _salt,
        string memory _routerStr
    ) external onlyAuth {
        address underlying = stringToAddress(_underlyingStr);
        address router = stringToAddress(_routerStr);

        address theia = address(new TheiaERC20{salt: _salt}(
            _name,
            _symbol,
            _decimals,
            underlying,
            router
        ));

        theia = _toLower(theia);
    }

    function _registerNewTheiaLocal(
        string memory _fromChainId,
        string memory _tokenStr,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        string memory _underlyingStr
    ) internal {
        if(!this.tokenSymbolExists(_symbol)) poolTokenSymbols.push(_symbol);
        symbolToToken[_symbol][_fromChainId] = _tokenStr;
        tokenToSymbol[_tokenStr][_fromChainId] = _symbol;
    }

    function _c3Fallback(
        bytes4 _selector,
        bytes calldata _data,
        bytes calldata _reason
    ) internal override returns (bool) {

        string memory fromChainIdStr;
        string memory name;
        string memory symbol;
        uint8 decimals;
        string memory underlyingStr;
        bytes32 salt;
        string memory routerStr;

        if (_selector == FuncDeployTheia) {
            (fromChainIdStr, name, symbol, decimals, underlyingStr, salt, routerStr) = abi.decode(
                _data,
                (string, string, string, uint8, string, bytes32, string)
            );
            emit LogNewTheiaFallBack(
                fromChainIdStr,
                name,
                symbol,
                underlyingStr
            );
            
        } else {
            emit LogFallback(_selector, _data, _reason);
        }

        return true;
    }

    function cID() public view returns (uint) {
        return block.chainid;
    }

    function getTokenBySymbol(string memory tokenSymbol, string memory toChainIdStr) external view returns(string memory tokenStr) {
        return(symbolToToken[tokenSymbol][toChainIdStr]);
    }
    function getSymbolByToken(string memory tokenStr, string memory toChainIdStr) external view returns(string memory tokenSymbol) {
        return(tokenToSymbol[tokenStr][toChainIdStr]);
    }

    function getPoolTokens() external view returns(string[] memory) {
        return(poolTokenSymbols);
    }

    function tokenSymbolExists(
        string memory tokenSymbol
    ) external view returns (bool) {
        uint256 len = poolTokenSymbols.length;
        for (uint256 i = 0; i < len; i++) {
            if (stringsEqual(tokenSymbol, poolTokenSymbols[i])) {
                return (true);
            }
        }
        return (false);
    }

    function stringsEqual(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        bytes32 ka = keccak256(abi.encode(a));
        bytes32 kb = keccak256(abi.encode(b));
        return (ka == kb);
    }

    function stringToAddress(string memory str) public pure returns (address) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length == 42, "Invalid address length");
        bytes memory addrBytes = new bytes(20);

        for (uint i = 0; i < 20; i++) {
            addrBytes[i] = bytes1(
                hexCharToByte(strBytes[2 + i * 2]) *
                    16 +
                    hexCharToByte(strBytes[3 + i * 2])
            );
        }

        return address(uint160(bytes20(addrBytes)));
    }

    function hexCharToByte(bytes1 char) internal pure returns (uint8) {
        uint8 byteValue = uint8(char);
        if (
            byteValue >= uint8(bytes1("0")) && byteValue <= uint8(bytes1("9"))
        ) {
            return byteValue - uint8(bytes1("0"));
        } else if (
            byteValue >= uint8(bytes1("a")) && byteValue <= uint8(bytes1("f"))
        ) {
            return 10 + byteValue - uint8(bytes1("a"));
        } else if (
            byteValue >= uint8(bytes1("A")) && byteValue <= uint8(bytes1("F"))
        ) {
            return 10 + byteValue - uint8(bytes1("A"));
        }
        revert("Invalid hex character");
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

    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
    

    function version() public pure returns (uint) {
        return 1;
    }

}