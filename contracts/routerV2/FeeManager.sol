// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Governor.sol";

abstract contract FeeManager is Governor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address[] public feeTokenList;
    mapping(address => uint256) public feeTokenIndexMap;

    constructor(
        address _feeToken,
        address _gov,
        address _c3callerProxy,
        uint256 _dappID
    ) Governor(_gov, _c3callerProxy, _dappID) {
        feeTokenList.push(_feeToken);
        feeTokenIndexMap[_feeToken] = 1;
    }

    event Withdrawal(
        address _oldFeeToken,
        address _recipient,
        uint256 _oldTokenContractBalance
    );

    event AddFeeToken(address _feeToken);
    event DelFeeToken(address _feeToken);

    uint256 public constant FROM_CHAIN_PAY = 1;
    uint256 public constant TO_CHAIN_PAY = 2;

    mapping(uint256 => mapping(address => uint256)) public _fromFeeConfigs; // key is fromChainID
    mapping(uint256 => mapping(address => uint256)) public _toFeeConfigs; // key is toChainID

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
        require(
            payFrom == FROM_CHAIN_PAY || payFrom == TO_CHAIN_PAY,
            "FM: Invalid payFrom"
        );
        require(feetokens.length == fee.length, "FM: Invalid list size");

        if (payFrom == FROM_CHAIN_PAY) {
            for (uint256 index = 0; index < feetokens.length; index++) {
                _toFeeConfigs[dstChainID][feetokens[index]] = fee[index];
            }
        } else if (payFrom == TO_CHAIN_PAY) {
            for (uint256 index = 0; index < feetokens.length; index++) {
                _fromFeeConfigs[srcChainID][feetokens[index]] = fee[index];
            }
        }
    }

    function payFee(address feeToken, uint256 fee) internal {
        require(feeTokenIndexMap[feeToken] > 0, "FM: feeToekn not exist");
        require(
            IERC20(feeToken).transferFrom(msg.sender, address(this), fee),
            "FM: Fee payment failed"
        );
    }

    function getFeeConfig(
        uint256 fromChainID,
        uint256 toChainID,
        address feeToken
    ) public view returns (uint256) {
        require(fromChainID > 0 || toChainID > 0, "FM: Invalid chainID");
        if (fromChainID == block.chainid) {
            return getToChainFee(toChainID, feeToken);
        } else if (toChainID == block.chainid) {
            return getFromChainFee(toChainID, feeToken);
        } else {
            return 0;
        }
    }

    function getFee(
        address feeToken,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 liquidity,
        uint256 amount,
        bool underlying
    ) public view returns (uint256) {
        uint256 baseFee = calcBaseSwapFee(fromChainID, toChainID, feeToken);
        if (baseFee == 0) return 0;
        else {
            uint256 feeFactor = underlying
                ? getFeeFactor(liquidity, amount)
                : 1000;
            return ((baseFee * feeFactor) / 1000);
        }
    }

    function getFeeFactor(
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

    function calcBaseSwapFee(
        uint256 fromChainID,
        uint256 toChainID,
        address feeToken
    ) public view returns (uint256) {
        return getFeeConfig(fromChainID, toChainID, feeToken);
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
}
