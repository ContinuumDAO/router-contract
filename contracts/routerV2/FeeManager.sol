// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GovernDapp.sol";
import "./IFeeManager.sol";

contract FeeManager is GovernDapp, IFeeManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address[] public feeTokenList;
    mapping(address => uint256) public feeTokenIndexMap;

    mapping(address => FeeParams) public feeParams;

    struct FeeParams {
        uint256 basePrice; // price in wei per gwei of relevent gasFee
        uint256 lowGas; // price in gwei
        uint256 normalGas;
        uint256 highGas;
        uint256 veryHighGas;
        uint256 lowGasFee; // price in gwei corresponding to lowGas
        uint256 normalGasFee; // price in gwei corresponding to normalGas
        uint256 highGasFee;
        uint256 veryHighGasFee;
    }

    constructor(
        address _feeToken,
        address _gov,
        address _c3callerProxy,
        uint256 _dappID
    ) GovernDapp(_gov, _c3callerProxy, _dappID) {
        feeTokenList.push(_feeToken);
        feeTokenIndexMap[_feeToken] = 1;
    }

    event Withdrawal(
        address _oldFeeToken,
        address _recipient,
        uint256 _oldTokenContractBalance
    );

    event AddFeeToken(address indexed _feeToken);
    event DelFeeToken(address indexed _feeToken);

    event SetLiqFee(address indexed _feeToken, uint256 _fee);

    uint256 public constant FROM_CHAIN_PAY = 1;
    uint256 public constant TO_CHAIN_PAY = 2;

    mapping(uint256 => mapping(address => uint256)) private _fromFeeConfigs; // key is fromChainID, value key is tokenAddress
    mapping(uint256 => mapping(address => uint256)) private _toFeeConfigs; // key is toChainID, value key is tokenAddress

    mapping(address => uint256) private _liqBaseFeeConfigs; // key is tokenAddress

    function setLiqBaseFee(
        address _feeToken,
        uint256 _baseFee
    ) external onlyGov returns (bool) {
        _liqBaseFeeConfigs[_feeToken] = _baseFee;
        emit SetLiqFee(_feeToken, _baseFee);
        return true;
    }

    function getBaseLiquidityFee(
        address _feeToken
    ) external view returns (uint256) {
        return _liqBaseFeeConfigs[_feeToken];
    }

    function addFeeToken(address _feeToken) external onlyGov returns (bool) {
        uint256 index = feeTokenList.length;
        feeTokenList.push(_feeToken);
        feeTokenIndexMap[_feeToken] = index + 1;
        emit AddFeeToken(_feeToken);
        return true;
    }

    function delFeeToken(address _feeToken) external onlyGov {
        require(feeTokenIndexMap[_feeToken] > 0, "FM: token not exist");
        uint256 index = feeTokenIndexMap[_feeToken];
        uint256 len = feeTokenList.length;
        if (index == len) {
            feeTokenList.pop();
        } else {
            address _token = feeTokenList[feeTokenList.length - 1];
            feeTokenList.pop();
            feeTokenList[index - 1] = _token;
            feeTokenIndexMap[_token] = index;
            feeTokenIndexMap[_feeToken] = 0;
        }
        emit DelFeeToken(_feeToken);
    }

    function setFeeConfig(
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 payFrom, // 1:from 2:to 0:free
        address[] memory feetokens,
        uint256[] memory fee // human readable * 100
    ) external onlyGov {
        require(srcChainID > 0 || dstChainID > 0, "FM: ChainID empty");
        require(
            payFrom == FROM_CHAIN_PAY || payFrom == TO_CHAIN_PAY,
            "FM: Invalid payFrom"
        );
        require(feetokens.length == fee.length, "FM: Invalid list size");

        for (uint256 index = 0; index < feetokens.length; index++) {
            require(
                feeTokenIndexMap[feetokens[index]] > 0,
                "FM: token not exist"
            );
            if (payFrom == FROM_CHAIN_PAY) {
                _fromFeeConfigs[block.chainid][feetokens[index]] = fee[index];
            } else if (payFrom == TO_CHAIN_PAY) {
                _toFeeConfigs[dstChainID][feetokens[index]] = fee[index];
            }
        }
    }

    function getFee(
        uint256 fromChainID,
        uint256 toChainID,
        address feeToken
    ) public view returns (uint256) {
        require(fromChainID > 0 || toChainID > 0, "FM: Invalid chainID");
        uint256 fee = getFromChainFee(fromChainID, feeToken);
        if (fee == 0) {
            fee = getToChainFee(toChainID, feeToken);
        }
        return fee;
    }

    function getLiquidityFee(
        address feeToken,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 liquidity,
        uint256 amount,
        bool underlying
    ) public view returns (uint256) {
        uint256 baseFee = getFee(fromChainID, toChainID, feeToken);
        if (baseFee == 0) return 0;
        else {
            uint256 feeFactor = underlying
                ? _getFeeFactor(liquidity, amount)
                : 1000;
            return ((baseFee * feeFactor) / 1000);
        }
    }

    function getLiquidityFeeFactor(
        uint256 liquidity,
        uint256 amount
    ) external pure returns (uint256 feeRate) {
        return _getFeeFactor(liquidity, amount);
    }

    function _getFeeFactor(
        uint256 liquidity,
        uint256 amount
    ) internal pure returns (uint256 fee) {
        require(liquidity > 0, "No destination liquidity");
        require(
            amount <= liquidity,
            "Amount must be less than destination liquidity"
        );

        // fee is 20 times higher to use all of the available liquidity
        uint16[21] memory feeFactor = [
            1000,
            1048,
            1190,
            1428,
            1760,
            2188,
            2710,
            3328,
            4040,
            4848,
            5750,
            6748,
            7840,
            9028,
            10310,
            11688,
            13160,
            14728,
            16390,
            18148,
            20000
        ];

        uint256 indx = (100 * amount) / liquidity;

        if (indx > 80) {
            indx = indx - 80;
            fee = feeFactor[indx];
        } else fee = 1000;

        return (fee);
    }

    function withdrawFee(
        address feeToken,
        uint256 amount
    ) external onlyGov returns (uint256) {
        uint256 bal = IERC20(feeToken).balanceOf(address(this));
        if (bal < amount) {
            amount = bal;
        }
        require(IERC20(feeToken).transfer(msg.sender, amount), "transfer fail");
        return (amount);
    }

    function getFromChainFee(
        uint256 fromChainID,
        address feeToken
    ) public view returns (uint256) {
        return _fromFeeConfigs[fromChainID][feeToken];
    }

    function getToChainFee(
        uint256 toChainID,
        address feeToken
    ) public view returns (uint256) {
        return _toFeeConfigs[toChainID][feeToken];
    }

    function _c3Fallback(
        bytes4 /*_selector*/,
        bytes calldata /*_data*/,
        bytes calldata /*_reason*/
    ) internal pure override returns (bool) {
        return true;
    }

    function setFeeTokenParams(
        address _feeToken,
        FeeParams memory fee
    ) external onlyGov {
        feeParams[_feeToken] = fee;
    }

    function getFeeTokenParams(
        address _feeToken
    ) public view returns (FeeParams memory) {
        return (feeParams[_feeToken]);
    }

    function getGasFee(
        uint256 toChainId,
        address feeToken
    ) public view returns (uint256) {
        if (feeParams[feeToken].basePrice == 0) {
            return 0;
        }

        uint256 gasPrice;
        assembly {
            gasPrice := gasprice()
        }

        if (toChainId == 1) {
            if (gasPrice < feeParams[feeToken].lowGas) {
                return (feeParams[feeToken].basePrice *
                    feeParams[feeToken].lowGasFee);
            } else if (gasPrice < feeParams[feeToken].normalGas) {
                return (feeParams[feeToken].basePrice *
                    feeParams[feeToken].normalGasFee);
            } else if (gasPrice < feeParams[feeToken].highGas) {
                return (feeParams[feeToken].basePrice *
                    feeParams[feeToken].highGasFee);
            } else {
                return (feeParams[feeToken].basePrice *
                    feeParams[feeToken].veryHighGasFee);
            }
        } else return (0); // only bother with Ethereum gas fees
    }
}
