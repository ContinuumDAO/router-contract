// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./Checkpoints.sol";
import {IStagingVault, RewardedToken} from "./IStagingVault.sol";

interface IVotingEscrow {
    function balanceOfNFTAt(
        uint256 _tokenId,
        uint256 _ts
    ) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function clock() external view returns (uint48);
}

interface ISwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(
        ExactInputParams memory params
    ) external returns (uint256 amountOut);
}

contract TheiaRewards {
    using Strings for *;
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace208;

    struct Fee {
        address token;
        uint256 amount;
    }

    uint48 public constant ONE_DAY = 1 days;
    uint256 public constant MULTIPLIER = 1 ether;
    uint48 public latestMidnight;
    uint48 public genesis;

    address stagingVault;
    address ve;

    address public govTHEIA; // for deciding on node quality scores
    address public rewardToken; // reward token
    address public feeToken; // eg. USDC
    address public swapRouter; // UniV3

    address public immutable WETH; // for middle-man in swap

    bool internal _swapEnabled;

    Checkpoints.Trace208 internal _baseEmissionRates; // THEIA / vePower

    mapping(uint256 => uint48) internal _lastClaimOf; // token ID => midnight ts starting last day they claimed
    mapping(uint256 => mapping(string => uint48)) _lastLiquidityClaimOf; // tokenId => token symbol => midnight ts starting last day they claimed
    mapping(uint256 => mapping(uint48 => Fee)) internal _feeReceivedFromChainAt;

    // events
    event BaseEmissionRateChange(
        uint256 _oldBaseEmissionRate,
        uint256 _newBaseEmissionRate
    );
    event NodeRewardThresholdChange(
        uint256 _oldMinimumThreshold,
        uint256 _newMinimumThreshold
    );
    event RewardTokenChange(
        address indexed _oldRewardToken,
        address indexed _newRewardToken
    );
    event FeeTokenChange(
        address indexed _oldFeeToken,
        address indexed _newFeeToken
    );
    event Claim(
        uint256 indexed _tokenId,
        uint256 _claimedReward,
        address indexed _rewardToken
    );
    event Withdrawal(
        address indexed _token,
        address indexed _recipient,
        uint256 _amount
    );
    event FeesReceived(
        address indexed _token,
        uint256 _amount,
        uint256 indexed _fromChainId
    );
    event Swap(
        address indexed _feeToken,
        address indexed _rewardToken,
        uint256 _amountIn,
        uint256 _amountOut
    );

    // errors
    error ERC6372InconsistentClock();
    error NoUnclaimedRewards();
    error InsufficientContractBalance(uint256 _balance, uint256 _required);
    error FeesAlreadyReceivedFromChain();

    modifier onlyTHEIA() {
        require(msg.sender == govTHEIA);
        _;
    }

    constructor(
        uint48 _firstMidnight,
        address _gov,
        address _rewardToken,
        address _feeToken,
        address _swapRouter,
        address _stagingVault,
        address _ve,
        uint256 _baseEmissionRate,
        address _weth
    ) {
        genesis = _firstMidnight;
        govTHEIA = _gov;
        rewardToken = _rewardToken;
        feeToken = _feeToken;
        swapRouter = _swapRouter;
        stagingVault = _stagingVault;
        ve = _ve;
        _setBaseEmissionRate(_baseEmissionRate);
        WETH = _weth;
        IERC20(_rewardToken).approve(_ve, type(uint256).max);
    }

    // external mutable

    function getTheiaGov() public view returns (address) {
        return govTHEIA;
    }

    function changeTheiaGov(
        address newGovTHEIA
    ) external onlyTHEIA returns (bool) {
        govTHEIA = newGovTHEIA;
        return true;
    }

    function setRewardToken(
        address _rewardToken,
        uint48 _firstMidnight,
        address _recipient
    ) external onlyTHEIA {
        address _oldRewardToken = rewardToken;
        rewardToken = _rewardToken;
        genesis = _firstMidnight;
        uint256 _oldTokenContractBalance = IERC20(_oldRewardToken).balanceOf(
            address(this)
        );

        if (_oldTokenContractBalance != 0) {
            _withdrawToken(
                _oldRewardToken,
                _recipient,
                _oldTokenContractBalance
            );
            emit Withdrawal(
                _oldRewardToken,
                _recipient,
                _oldTokenContractBalance
            );
        }

        emit RewardTokenChange(_oldRewardToken, _rewardToken);
    }

    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    function setFeeToken(
        address _feeToken,
        address _recipient
    ) external onlyTHEIA {
        address _oldFeeToken = feeToken;
        feeToken = _feeToken;
        uint256 _oldTokenContractBalance = IERC20(_oldFeeToken).balanceOf(
            address(this)
        );

        if (_oldTokenContractBalance != 0) {
            _withdrawToken(_oldFeeToken, _recipient, _oldTokenContractBalance);
            emit Withdrawal(_oldFeeToken, _recipient, _oldTokenContractBalance);
        }

        emit FeeTokenChange(_oldFeeToken, _feeToken);
    }

    function getFeeToken() external view returns (address) {
        return feeToken;
    }

    function setSwapEnabled(bool _enabled) external onlyTHEIA {
        _swapEnabled = _enabled;
    }

    function setBaseEmissionRate(uint256 _baseEmissionRate) external onlyTHEIA {
        _setBaseEmissionRate(_baseEmissionRate);
    }

    function withdrawToken(
        address _token,
        address _recipient,
        uint256 _amount
    ) external onlyTHEIA {
        _withdrawToken(_token, _recipient, _amount);
        emit Withdrawal(_token, _recipient, _amount);
    }

    function claimLiquidityRewards(
        uint256 _tokenId,
        string memory _tokenSymbol
    ) external returns (uint256) {
        require(
            IVotingEscrow(ve).ownerOf(_tokenId) == msg.sender,
            "Theia Rewards: Not owner of this veTHEIA"
        );

        uint48 _latestMidnight = _getLatestMidnight();

        if (_latestMidnight == _lastLiquidityClaimOf[_tokenId][_tokenSymbol]) {
            revert NoUnclaimedRewards();
        }

        _updateLatestLiquidityMidnight(_tokenId, _tokenSymbol, _latestMidnight);

        uint256 rewards = this.calculateLiquidityRewards(
            _tokenId,
            _tokenSymbol
        );
        require(rewards > 0, "Theia Rewards: No unclaimed rewards");

        IERC20(rewardToken).safeTransfer(msg.sender, rewards);
        return (rewards);
    }

    function calculateBaseRewards(
        uint256 tokenId
    ) external view returns (uint256) {
        uint48 _latestMidnight = _getLatestMidnight();

        // base rewards for simply holding veTHEIA
        uint256 baseRewards = _calculateBaseRewardsOf(tokenId, _latestMidnight);

        return (baseRewards);
    }

    function claimBaseRewards(uint256 _tokenId) external returns (uint256) {
        require(
            IVotingEscrow(ve).ownerOf(_tokenId) == msg.sender,
            "Theia Rewards: Not owner of this veTHEIA"
        );

        uint48 _latestMidnight = _getLatestMidnight();

        if (_latestMidnight == _lastClaimOf[_tokenId]) {
            revert NoUnclaimedRewards();
        }

        _updateLatestMidnight(_latestMidnight);

        uint256 rewards = this.calculateBaseRewards(_tokenId);
        require(rewards > 0, "Theia Rewards: No unclaimed rewards");

        IERC20(rewardToken).safeTransfer(msg.sender, rewards);
        return (rewards);
    }

    function calculateLiquidityRewards(
        uint256 _tokenId,
        string memory _tokenSymbol
    ) external view returns (uint256) {
        uint48 _latestMidnight = _getLatestMidnight();

        uint256 liquidityRewards = calculateLiquidityRewardsOf(
            _tokenId,
            _tokenSymbol,
            _latestMidnight
        );

        return (liquidityRewards);
    }

    function receiveFees(
        address _token,
        uint256 _amount,
        uint256 _fromChainId
    ) external {
        require(_token == feeToken || _token == rewardToken);

        if (
            _feeReceivedFromChainAt[_fromChainId][IVotingEscrow(ve).clock()]
                .amount != 0
        ) {
            revert FeesAlreadyReceivedFromChain();
        }

        require(
            IERC20(_token).transferFrom(msg.sender, address(this), _amount)
        );

        _feeReceivedFromChainAt[_fromChainId][IVotingEscrow(ve).clock()] = Fee(
            _token,
            _amount
        );
        emit FeesReceived(_token, _amount, _fromChainId);
    }

    function updateLatestMidnight() external {
        uint48 _latestMidnight = _getLatestMidnight();
        _updateLatestMidnight(_latestMidnight);
    }

    function updateLatestLiquidityMidnight(
        uint256 _tokenId,
        string memory _tokenSymbol
    ) external {
        uint48 _latestMidnight = _getLatestMidnight();
        _updateLatestLiquidityMidnight(_tokenId, _tokenSymbol, _latestMidnight);
    }

    function swapFeeToReward(
        uint256 _amountIn,
        uint256 _deadline,
        uint256 _uniFeeWETH,
        uint256 _uniFeeReward
    ) external returns (uint256 _amountOut) {
        require(_swapEnabled);
        uint256 _contractBalance = IERC20(feeToken).balanceOf(address(this));

        if (_amountIn > _contractBalance) {
            _amountIn = _contractBalance;
        }

        IERC20(feeToken).approve(swapRouter, _amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(
                    feeToken,
                    _uniFeeWETH,
                    WETH,
                    _uniFeeReward,
                    rewardToken
                ),
                recipient: address(this),
                deadline: _deadline,
                amountIn: _amountIn,
                amountOutMinimum: 0
            });

        _amountOut = ISwapRouter(swapRouter).exactInput(params);

        emit Swap(feeToken, rewardToken, _amountIn, _amountOut);
    }

    // external view
    function _getLatestMidnight() internal view returns (uint48) {
        uint48 _latestMidnight = latestMidnight;
        uint48 _time = IVotingEscrow(ve).clock();

        if ((_time - _latestMidnight) < ONE_DAY) {
            return _latestMidnight;
        }

        while (_latestMidnight < (_time - ONE_DAY)) {
            _latestMidnight += ONE_DAY;
        }

        return _latestMidnight;
    }

    // only call when assuming _latestMidnight is up-to-date
    function calculateLiquidityRewardsOf(
        uint256 _tokenId,
        string memory _tokenSymbol,
        uint48 _latestMidnight
    ) internal view returns (uint256) {
        (bool exists, ) = IStagingVault(stagingVault).tokenSymbolExists(
            _tokenSymbol
        );
        require(exists, "TheiaRewards: This token has never received rewards");

        string[] memory rewardChains = IStagingVault(stagingVault)
            .getRewardToken(_tokenSymbol)
            .toChainIdsStr;

        uint48 _lastClaimed = _lastLiquidityClaimOf[_tokenId][_tokenSymbol];

        // if they have never claimed, ensure their last claim is set to a midnight timestamp
        if (_lastClaimed == 0) {
            _lastClaimed = genesis;
        }

        // number of days between latest midnight and last claimed
        uint48 _daysUnclaimed = (_latestMidnight - _lastClaimed) / ONE_DAY;
        // ensure a midnight has passed since last claim
        assert(_daysUnclaimed * ONE_DAY == (_latestMidnight - _lastClaimed));

        uint256 reward;
        uint256 liquidity;
        uint256 rewardRate;

        // start at the midnight following their last claim, increment by one day at a time
        // continue until rewards counted for latest midnight
        for (
            uint48 i = _lastClaimed + ONE_DAY;
            i <= _lastClaimed + (_daysUnclaimed * ONE_DAY);
            i += ONE_DAY
        ) {
            uint256 _time = uint256(i);
            for (uint j; j < rewardChains.length; j++) {
                liquidity = IStagingVault(stagingVault).getLiquidityOfAt(
                    _tokenId,
                    _tokenSymbol,
                    rewardChains[i],
                    _time
                );

                rewardRate = IStagingVault(stagingVault).getRewardRate(
                    _tokenSymbol,
                    rewardChains[i],
                    _time
                );

                reward += liquidity * rewardRate;
            }
        }

        return reward;
    }

    // only call when assuming _latestMidnight is up-to-date
    function _calculateBaseRewardsOf(
        uint256 _tokenId,
        uint48 _latestMidnight
    ) internal view returns (uint256) {
        uint48 _lastClaimed = _lastClaimOf[_tokenId];

        // if they have never claimed, ensure their last claim is set to a midnight timestamp
        if (_lastClaimed == 0) {
            _lastClaimed = genesis;
        }

        // number of days between latest midnight and last claimed
        uint48 _daysUnclaimed = (_latestMidnight - _lastClaimed) / ONE_DAY;
        // ensure a midnight has passed since last claim
        assert(_daysUnclaimed * ONE_DAY == (_latestMidnight - _lastClaimed));

        uint256 _reward;
        uint256 _prevDayVePower;

        // start at the midnight following their last claim, increment by one day at a time
        // continue until rewards counted for latest midnight
        for (
            uint48 i = _lastClaimed + ONE_DAY;
            i <= _lastClaimed + (_daysUnclaimed * ONE_DAY);
            i += ONE_DAY
        ) {
            uint256 _time = uint256(i);
            uint256 _vePower = IVotingEscrow(ve).balanceOfNFTAt(
                _tokenId,
                _time
            );

            // check if ve power is zero (meaning the token ID didn't exist at this time).
            // previous day ve power is the ve power of the previous iteration of this loop, if it is zero then
            // the midnight in question is less than a day since the token ID was created. This means they don't
            // get rewards for this day, and their rewards instead start at the following midnight.
            if (_vePower == 0 || _prevDayVePower == 0) {
                _prevDayVePower = _vePower;
                continue;
            }

            uint256 _baseEmissionRate = baseEmissionRateAt(i);

            _reward += _calculateBaseRewards(_vePower, _baseEmissionRate);
        }

        return _reward;
    }

    // public view
    function baseEmissionRateAt(
        uint256 _timestamp
    ) public view returns (uint256) {
        return
            _baseEmissionRates.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    function baseEmissionRate() external view returns (uint256) {
        return _baseEmissionRates.latest();
    }

    function liquidityEmissionRate(
        string memory _tokenSymbol,
        string memory _chainIdStr,
        uint256 _timeStamp
    ) public view returns (uint256) {
        return (
            IStagingVault(stagingVault).getRewardRate(
                _tokenSymbol,
                _chainIdStr,
                _timeStamp
            )
        );
    }

    // internal mutable
    function _updateLatestMidnight(uint48 _latestMidnight) internal {
        latestMidnight = _latestMidnight;
    }

    function _updateLatestLiquidityMidnight(
        uint256 _tokenId,
        string memory _tokenSymbol,
        uint48 _latestMidnight
    ) internal {
        _lastLiquidityClaimOf[_tokenId][_tokenSymbol] = _latestMidnight;
    }

    function _withdrawToken(
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        require(IERC20(_token).transfer(_recipient, _amount));
    }

    function _setBaseEmissionRate(uint256 _baseEmissionRate) internal {
        require(
            _baseEmissionRate <= MULTIPLIER / 100,
            "Cannot set base rewards per vepower-day higher than 1%."
        );
        uint208 _baseEmissionRate208 = SafeCast.toUint208(_baseEmissionRate);
        (
            uint256 _oldBaseEmissionRate,
            uint256 _newBaseEmissionRate
        ) = _baseEmissionRates.push(
                IVotingEscrow(ve).clock(),
                _baseEmissionRate208
            );
        emit BaseEmissionRateChange(_oldBaseEmissionRate, _newBaseEmissionRate);
    }

    // internal pure
    function _calculateBaseRewards(
        uint256 _votingPower,
        uint256 _baseRewards
    ) internal pure returns (uint256) {
        return (_votingPower * (_baseRewards)) / MULTIPLIER;
    }
}
