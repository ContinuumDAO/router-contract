// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Checkpoints.sol";
import "./GovernDapp.sol";
import {TheiaERC20} from "./TheiaERC20.sol";
import "./ITheiaERC20.sol";
import "./FeeManager.sol";
import {ITheiaRewards} from "./ITheiaRewards.sol";

// helper methods for interacting with ERC20 tokens and sending NATIVE that do not consistently return true/false
library TransferHelper {
    function safeTransferNative(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: NATIVE_TRANSFER_FAILED");
    }
}

interface IVotingEscrow {
    function balanceOfNFTAt(
        uint256 _tokenId,
        uint256 _ts
    ) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function clock() external view returns (uint48);
}

interface IwNATIVE {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface ITheiaERC20Extended {
    function underlyingIsMinted() external view returns (bool);
}

contract StagingVault is GovernDapp {
    using Strings for *;
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace208;

    address public immutable wNATIVE;
    address public ve;
    address public theiaRewards;
    address public feeManager;
    uint256 nonceGlobal;

    // delay for timelock functions
    uint256 public liquidityDelay = 7 days;

    mapping(address => bool) public isOperator;
    address[] public operators;

    event LogFallback(bytes4 selector, bytes data, bytes reason);

    constructor(
        address _txSender,
        address _c3callerProxy,
        uint256 _dappID,
        address _gov,
        address _feeManager,
        address _wNATIVE,
        address _ve
    ) GovernDapp(_gov, _c3callerProxy, _txSender, _dappID) {
        wNATIVE = _wNATIVE;
        feeManager = _feeManager;
        ve = _ve;
    }

    string[] stakedTokenSymbols;

    event AddLiquidity(
        string tokenStr,
        string lp,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce,
        string sourceTx
    );

    event RemoveLiquidity(
        address token,
        address liquidityProvider,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce,
        string sourceTx
    );

    event StagingToLiquidityFail(
        address indexed liquidityProvider,
        address token,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 nonce,
        uint256 feePaid,
        bytes reason
    );

    event LiquidityToStagingFail(
        address token,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 nonce,
        uint256 feePaid,
        bytes reason
    );

    event ReportLiquidityAttachment(
        uint256 tokenId,
        string lp,
        string fromChainId,
        string tokenStr,
        uint256 amount,
        uint256 nonce
    );

    event ReportLiquidityDetachment(
        uint256 tokenId,
        string lp,
        string fromChainId,
        string tokenStr,
        uint256 amount,
        uint256 nonce
    );

    event SetRewardFlag(string tokenSymbol, string tokenStr, bool flag);

    bytes4 public FuncStagingToLiquidity =
        bytes4(
            keccak256(
                "stagingToLiquidity(string,string,uint256,uint256,bytes32,uint256)"
            )
        );

    bytes4 public FuncLiquidityToStaging =
        bytes4(
            keccak256(
                "liquidityToStaging(string,string,uint256,uint256,bytes32,uint256)"
            )
        );

    struct RewardedToken {
        string symbol;
        uint256 standardRewardRate;
        string[] tokensStr;
        string[] toChainIdsStr;
        uint256[] rateFactors;
    }

    mapping(string => Checkpoints.Trace208) internal rewardRate; //  On veTHEIA chain: token symbol => checkpointed standard reward rate
    mapping(string => mapping(string => Checkpoints.Trace208))
        internal modifiedRewardRate; //  On veTHEIA chain: token symbol => chainIdStr => checkpointed reward rate inc rateFactor
    mapping(uint256 => mapping(string => mapping(string => Checkpoints.Trace208))) liquidityOfAt; // token ID => token symbol => chainIdStr => checkpointed liquidity

    mapping(string => bool) public rewardedEVM; // On each EVM chain: token address => rewarded flag
    mapping(string => mapping(address => uint256)) public stagingTokens; // On each EVM chain: token address => provider => amount

    mapping(string => bool) public rewarded; // On veTHEIA chain: token address => rewarded flag
    mapping(string => mapping(string => uint256)) public rateFactorEndTime; // On veTHEIA chain: token symbol => chainId => time
    mapping(uint256 => mapping(string => mapping(string => uint256)))
        public liquidityRemovalTime; // On veTHIEA chain: tokenId => token symbol => chainId => timestamp
    mapping(string => RewardedToken) public rewardedTokens; // On veTHIEA chain: token symbol => struct
    mapping(string => mapping(string => string)) public symbolToToken; // On veTHIEA chain: liquidity symbol => toChainId => token address
    mapping(string => mapping(string => string)) public tokenToSymbol; // On veTHIEA chain: token address => tochainId => liquidity symbol
    mapping(uint256 => mapping(string => uint256)) public liquidityAll; // On veTHIEA chain: tokenId => token symbol => amount
    mapping(string => mapping(string => uint256)) public liquidityByChain; // On veTHEIA chain: token symbol => chainId => amount
    mapping(uint256 => mapping(string => mapping(string => uint256))) liquidityByTokenId; // On veTHEIA chain: tokenId => token symbol => chainId => amount
    mapping(string => uint256) public liquidityTotalAll; // On veTHIEA chain: token symbol => total liquidity (all chains)
    mapping(uint256 => bool) public completed; // On veTHIEA chain: nonce => completed flag


    modifier onlyAuth() {
        require(
            isOperator[msg.sender] || isCaller(msg.sender),
            "Theia StagingVault: AUTH FORBIDDEN"
        );
        _;
    }

    function cID() public view returns (uint) {
        return block.chainid;
    }

    function version() public pure returns (uint) {
        return 1;
    }

    function setLiquidityDelay(uint _delay) external onlyGov returns (bool) {
        liquidityDelay = _delay;
        return true;
    }

    function getLiquidityDelay() external view returns (uint256) {
        return (liquidityDelay);
    }

    function setUp(
        address _ve,
        address _theiaRewards
    ) external onlyGov returns (bool) {
        ve = _ve;
        theiaRewards = _theiaRewards;
        return true;
    }

    function changeTheiaRewards(
        address _theiaRewards
    ) external onlyGov returns (bool) {
        theiaRewards = _theiaRewards;
        return true;
    }

    function getTheiaRewards() external view returns (address) {
        return (theiaRewards);
    }

    function changeVotingEscrow(
        address _votingEscrow
    ) external onlyGov returns (bool) {
        ve = _votingEscrow;
        return true;
    }

    function getVotingEscrow() external view returns (address) {
        return (address(ve));
    }

    function addRewardToken(
        string memory tokenSymbol,
        string memory tokenStr,
        uint256 standardRewardRate,
        string memory toChainIdStr,
        uint256 rateFactor,
        string memory targetStr
    ) external onlyGov {
        require(
            !rewarded[tokenSymbol],
            "Theia StagingVault: Token is already listed for rewards"
        );

        address token = stringToAddress(tokenStr);
        require(
            ITheiaERC20Extended(token).underlyingIsMinted() == false,
            "Theia StagingVault: Cannot add a rewarded token without an underlying asset pool"
        );

        tokenStr = _toLower(tokenStr);

        (bool exists, ) = this.tokenSymbolExists(tokenSymbol);
        if (!exists) stakedTokenSymbols.push(tokenSymbol);

        rewarded[tokenSymbol] = true;

        rewardedTokens[tokenSymbol].standardRewardRate = standardRewardRate;
        rewardedTokens[tokenSymbol].tokensStr.push(tokenStr);
        rewardedTokens[tokenSymbol].toChainIdsStr.push(toChainIdStr);
        rewardedTokens[tokenSymbol].rateFactors.push(rateFactor);

        uint208 rewardRate208 = SafeCast.toUint208(standardRewardRate);
        rewardRate[tokenSymbol].push(IVotingEscrow(ve).clock(), rewardRate208);

        uint256 toChainId;
        uint208 modifiedRate208;
        bool ok;
        string memory funcCall = "setRewardFlag(string,string,bool)";
        bytes memory callData;

        (toChainId, ok) = strToUint(toChainIdStr);
        require(ok, "Theia StagingVault:sourceChain invalid");

        symbolToToken[tokenSymbol][toChainIdStr] = tokenStr;
        tokenToSymbol[tokenStr][toChainIdStr] = tokenSymbol;

        modifiedRate208 = SafeCast.toUint208(
            (standardRewardRate * rateFactor) / 1000
        );
        modifiedRewardRate[tokenSymbol][toChainIdStr].push(
            IVotingEscrow(ve).clock(),
            modifiedRate208
        );

        if (toChainId == cID()) {
            rewardedEVM[tokenStr] = true;
        } else {
            callData = abi.encodeWithSignature(
                funcCall,
                tokenSymbol,
                tokenStr,
                true
            );

            c3call(targetStr, toChainIdStr, callData);
        }
    }

    // On each EVM chain
    function setRewardFlag(
        string memory tokenSymbol,
        string memory tokenStr,
        bool rewardFlag
    ) external onlyAuth {
        address token = stringToAddress(tokenStr);
        require(
            ITheiaERC20Extended(token).underlyingIsMinted() == false,
            "Theia StagingVault: Cannot add a rewarded token without an underlying asset pool"
        );

        tokenStr = _toLower(tokenStr);

        rewardedEVM[tokenStr] = rewardFlag;
        emit SetRewardFlag(tokenSymbol, tokenStr, rewardFlag);
    }

    function removeRewardToken(
        string memory tokenSymbol,
        string[] memory toChainIdsStr,
        string[] memory targetsStr
    ) external onlyAuth {
        require(
            rewarded[tokenSymbol],
            "Theia StagingVault: Token is not listed for rewards"
        );

        rewarded[tokenSymbol] = false;
        string memory tokenStr;

        rewardedTokens[tokenSymbol].standardRewardRate = 0;
        rewardedTokens[tokenSymbol].tokensStr = [""];
        rewardedTokens[tokenSymbol].toChainIdsStr = [""];
        rewardedTokens[tokenSymbol].rateFactors = [0];

        rewardRate[tokenSymbol].push(IVotingEscrow(ve).clock(), 0);

        uint256 len = toChainIdsStr.length;

        uint256 toChainId;
        bool ok;
        string memory funcCall = "setRewardFlag(string,string,bool)";
        bytes memory callData;

        for (uint256 i = 0; i < len; i++) {
            string memory toChainIdStr = toChainIdsStr[i];
            (toChainId, ok) = strToUint(toChainIdStr);
            require(ok, "Theia StagingVault:sourceChain invalid");

            modifiedRewardRate[tokenSymbol][toChainIdStr].push(
                IVotingEscrow(ve).clock(),
                0
            );

            tokenStr = symbolToToken[tokenSymbol][toChainIdStr];

            if (toChainId == cID()) {
                rewardedEVM[tokenStr] = false;
            } else {
                callData = abi.encodeWithSignature(
                    funcCall,
                    tokenSymbol,
                    tokenStr,
                    false
                );

                c3call(targetsStr[i], toChainIdStr, callData);
            }
        }
    }

    function updateChainRewardedToken(
        string memory tokenSymbol,
        uint256 standardRewardRate,
        string memory tokenStr,
        string memory chainIdStr,
        uint256 rateFactor
    ) external onlyGov {
        require(
            rewarded[tokenSymbol],
            "Theia StagingVault: Token was not listed for rewards"
        );
        tokenStr = _toLower(tokenStr);
        rewardedTokens[tokenSymbol].standardRewardRate = standardRewardRate;

        uint208 rewardRate208 = SafeCast.toUint208(standardRewardRate);
        rewardRate[tokenSymbol].push(IVotingEscrow(ve).clock(), rewardRate208);

        uint256 len = rewardedTokens[tokenSymbol].toChainIdsStr.length;

        symbolToToken[tokenSymbol][chainIdStr] = tokenStr;
        tokenToSymbol[tokenStr][chainIdStr] = tokenSymbol;

        uint208 modifiedRate208;

        for (uint256 i = 0; i < len; i++) {
            if (
                stringsEqual(
                    rewardedTokens[tokenSymbol].toChainIdsStr[i],
                    chainIdStr
                )
            ) {
                rewardedTokens[tokenSymbol].tokensStr[i] = tokenStr;
                rewardedTokens[tokenSymbol].rateFactors[i] = rateFactor;
                modifiedRate208 = SafeCast.toUint208(
                    (standardRewardRate * rateFactor) / 1000
                );
                modifiedRewardRate[tokenSymbol][chainIdStr].push(
                    IVotingEscrow(ve).clock(),
                    modifiedRate208
                );
                return;
            }
        }
        // otherwise add as new chain
        rewardedTokens[tokenSymbol].toChainIdsStr.push(chainIdStr);
        rewardedTokens[tokenSymbol].tokensStr.push(tokenStr);
        rewardedTokens[tokenSymbol].rateFactors.push(rateFactor);
        modifiedRate208 = SafeCast.toUint208(
            (standardRewardRate * rateFactor) / 1000
        );
        modifiedRewardRate[tokenSymbol][chainIdStr].push(
            IVotingEscrow(ve).clock(),
            modifiedRate208
        );

        return;
    }

    function setStandardRewardRate(
        string memory tokenSymbol,
        uint256 _standardRewardRate
    ) external onlyGov {
        require(
            rewarded[tokenSymbol],
            "Theia StagingVault: Token was not listed for rewards"
        );
        rewardedTokens[tokenSymbol].standardRewardRate = _standardRewardRate;
        uint208 rewardRate208 = SafeCast.toUint208(_standardRewardRate);
        rewardRate[tokenSymbol].push(IVotingEscrow(ve).clock(), rewardRate208);
    }

    function setRewardFactor(
        string memory tokenSymbol,
        string memory chainIdStr,
        uint256 _rateFactor
    ) external onlyGov {
        require(
            rewarded[tokenSymbol],
            "Theia StagingVault: Token is not listed for rewards"
        );
        require(_rateFactor <= 10000); // cannot set reward rate to more than 10x of standard

        uint256 len = rewardedTokens[tokenSymbol].toChainIdsStr.length;

        for (uint256 i = 0; i < len; i++) {
            if (
                stringsEqual(
                    rewardedTokens[tokenSymbol].toChainIdsStr[i],
                    chainIdStr
                )
            ) {
                rewardedTokens[tokenSymbol].rateFactors[i] = _rateFactor;
                uint208 modifiedRate208;
                uint256 standardRewardRate = rewardedTokens[tokenSymbol]
                    .standardRewardRate;
                modifiedRate208 = SafeCast.toUint208(
                    (standardRewardRate * _rateFactor) / 1000
                );
                modifiedRewardRate[tokenSymbol][chainIdStr].push(
                    IVotingEscrow(ve).clock(),
                    modifiedRate208
                );
                // modifiedRewardRate[tokenSymbol][chainIdStr] = _modifiedRewardRate;

                return;
            }
        }
        revert("Theia StagingVault: chainIdStr not found");
    }

    function setRateTimeToken(
        string memory tokenSymbol,
        string memory chainIdStr,
        uint256 validDuration
    ) external onlyGov {
        require(
            rewarded[tokenSymbol],
            "Theia StagingVault: Token was not listed for rewards"
        );
        rateFactorEndTime[tokenSymbol][chainIdStr] =
            validDuration +
            block.timestamp;
    }

    function depositStaging(
        string memory tokenStr,
        uint256 amount
    ) external returns (uint256) {
        tokenStr = _toLower(tokenStr);
        require(
            rewardedEVM[tokenStr],
            "Theia StagingVault: Token does not receive rewards"
        );
        require(amount > 0, "Theia StagingVault: Cannot deposit a zero amount");
        address token = stringToAddress(tokenStr);
        address underlying = TheiaERC20(token).underlying();
        require(
            IERC20(underlying).balanceOf(msg.sender) >= amount,
            "Theia StagingVault: User does not have sufficient balance"
        );

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        stagingTokens[tokenStr][msg.sender] += amount;
        return (stagingTokens[tokenStr][msg.sender]);
    }

    function depositStagingNative(
        string memory tokenStr
    ) external payable returns (uint256) {
        require(wNATIVE != address(0), "Theia StagingVault: zero wNATIVE");
        require(
            rewardedEVM[tokenStr],
            "Theia StagingVault: Token does not receive rewards"
        );
        address token = stringToAddress(tokenStr);
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "Theia StagingVault:underlying is not wNATIVE"
        );
        IwNATIVE(wNATIVE).deposit{value: msg.value}();
        assert(IwNATIVE(wNATIVE).transfer(token, msg.value));

        return msg.value;
    }

    function withdrawStaging(
        string memory tokenStr,
        uint256 amount,
        address to
    ) external returns (uint256) {
        tokenStr = _toLower(tokenStr);
        require(
            stagingTokens[tokenStr][msg.sender] >= amount,
            "Theia StagingVault: Insufficient funds in StagingVault to withdraw"
        );
        require(
            amount > 0,
            "Theia StagingVault: Cannot withdraw a zero amount"
        );
        address token = stringToAddress(tokenStr);
        address underlying = TheiaERC20(token).underlying();
        IERC20(underlying).safeTransfer(to, amount);
        stagingTokens[tokenStr][msg.sender] -= amount;
        return (stagingTokens[tokenStr][msg.sender]);
    }

    function withdrawStagingNative(
        string memory tokenStr,
        uint256 amount,
        address to
    ) external returns (uint256) {
        require(wNATIVE != address(0), "Theia StagingVault: zero wNATIVE");
        address token = stringToAddress(tokenStr);
        require(
            ITheiaERC20(token).underlying() == wNATIVE,
            "Theia StagingVault:underlying is not wNATIVE"
        );

        IwNATIVE(wNATIVE).withdraw(amount);
        TransferHelper.safeTransferNative(to, amount);
        return amount;
    }

    function stagingToLiquidityLocal(
        string memory tokenStr, // liquidity token on this chain
        string memory lp, // owner of tokenId
        uint256 tokenId, // veTHEAI ID
        uint256 amount,
        uint256 nonce
    ) internal {
        address liquidityProvider = stringToAddress(lp);
        address token = stringToAddress(tokenStr);
        address underlying = ITheiaERC20(token).underlying();
        IERC20(underlying).approve(token, amount);
        tokenStr = _toLower(tokenStr);
        require(
            rewardedEVM[tokenStr],
            "Theia StagingVault: Token does not receive rewards"
        );
        require(
            stagingTokens[tokenStr][liquidityProvider] >= amount,
            "Theia StagingVault: Liquidity provider has insufficient funds in the stagingVault"
        );

        stagingTokens[tokenStr][liquidityProvider] -= amount;

        ITheiaERC20(token).deposit(amount, address(this));

        _reportLiquidityAttachmentLocal(
            cID().toString(),
            lp,
            tokenId,
            tokenStr,
            amount,
            nonce
        );

        emit AddLiquidity(tokenStr, lp, tokenId, amount, nonce, "");
    }

    function stagingToLiquidity(
        string memory fromTargetStr,
        string memory tokenStr, // liquidity token on this chain
        string memory lp, // owner of tokenId
        uint256 tokenId, // veTHEAI ID
        uint256 amount,
        uint256 nonce,
        string memory feeTokenStr,
        uint256 feePaid
    ) external onlyAuth {
        address liquidityProvider = stringToAddress(lp);
        address token = stringToAddress(tokenStr);
        address underlying = ITheiaERC20(token).underlying();
        IERC20(underlying).approve(token, amount);
        tokenStr = _toLower(tokenStr);
        require(
            rewardedEVM[tokenStr],
            "Theia StagingVault: Token does not receive rewards"
        );
        require(
            stagingTokens[tokenStr][liquidityProvider] >= amount,
            "Theia StagingVault: Token does not receive rewards"
        );

        (, string memory fromChainIdStr, string memory sourceTx) = context();

        address feeToken = stringToAddress(feeTokenStr);

        uint256 gasFee = FeeManager(feeManager).getGasFee(cID(), feeToken); // only charge gas fee for liquidity provision

        if (gasFee > feePaid)
            revert("Theia StagingVault: Insufficient Fee Paid");

        ITheiaERC20(token).deposit(amount, address(this));

        (, bool ok) = strToUint(fromChainIdStr);
        require(ok, "Theia StagingVault:sourceChain invalid");

        string
            memory funcCall = "reportLiquidityAttachment(string,string,uint256,string,uint256,uint256)";
        bytes memory callData = abi.encodeWithSignature(
            funcCall,
            cID().toString(),
            lp,
            tokenId,
            tokenStr,
            amount,
            nonce
        );

        c3call(fromTargetStr, fromChainIdStr, callData);

        emit AddLiquidity(tokenStr, lp, tokenId, amount, nonce, sourceTx);
    }

    function liquidityToStagingLocal(
        string memory tokenStr, // liquidity token on this chain
        string memory lp, // owner of tokenId
        uint256 tokenId, // veTHEAI ID
        uint256 amount,
        uint256 nonce
    ) internal {
        address liquidityProvider = stringToAddress(lp);
        address token = stringToAddress(tokenStr);
        tokenStr = _toLower(tokenStr);
        (uint256 availableLiquidity, uint256 decimals) = this.getLiquidity(
            token
        );
        require(
            availableLiquidity >= amount,
            "Theia StagingVault: Insufficient liquidity to withdraw"
        );

        ITheiaERC20(token).withdraw(amount, address(this));

        stagingTokens[tokenStr][liquidityProvider] += amount;

        _reportLiquidityDetachmentLocal(
            cID().toString(),
            lp,
            tokenId,
            tokenStr,
            amount,
            nonce
        );

        emit RemoveLiquidity(
            token,
            liquidityProvider,
            tokenId,
            amount,
            nonce,
            ""
        );
    }

    function liquidityToStaging(
        string memory fromTargetStr,
        string memory tokenStr, // liquidity token on this chain
        string memory lp, // owner of tokenId
        uint256 tokenId, // veTHEAI ID
        uint256 amount,
        uint256 nonce,
        string memory feeTokenStr,
        uint256 feePaid // same fee as router usage, to avoid exploit
    ) external onlyAuth {
        address liquidityProvider = stringToAddress(lp);
        address token = stringToAddress(tokenStr);
        tokenStr = _toLower(tokenStr);
        (uint256 availableLiquidity, uint256 decimals) = this.getLiquidity(
            token
        );
        require(
            availableLiquidity >= amount,
            "Theia StagingVault: Insufficient liquidity to withdraw"
        );

        (, string memory fromChainIdStr, string memory sourceTx) = context();

        address feeToken = stringToAddress(feeTokenStr);

        {
            (uint256 fromChainId, bool ok) = strToUint(fromChainIdStr);
            require(ok, "Theia StagingVault:sourceChain invalid");
            // TODO FIXME
            uint256 liquidityFee = FeeManager(feeManager).getLiquidityFee(
                feeToken,
                fromChainId,
                cID(),
                availableLiquidity,
                amount
            );
            uint256 gasFee = FeeManager(feeManager).getGasFee(cID(), feeToken);
            uint256 fee = liquidityFee + gasFee;

            if (fee > feePaid)
                revert("Theia StagingVault: Insufficient Fee Paid");
        }

        ITheiaERC20(token).withdraw(amount, address(this));

        stagingTokens[tokenStr][liquidityProvider] += amount;

        string
            memory funcCall = "reportLiquidityDetachment(string,string,uint256,string,uint256,uint256)";
        bytes memory callData = abi.encodeWithSignature(
            funcCall,
            cID().toString(),
            lp,
            tokenId,
            tokenStr,
            amount,
            nonce
        );

        c3call(fromTargetStr, fromChainIdStr, callData);

        emit RemoveLiquidity(
            token,
            liquidityProvider,
            tokenId,
            amount,
            nonce,
            sourceTx
        );
    }

    function attachLiquidity(
        uint256 tokenId,
        string memory targetStr,
        string memory tokenSymbol,
        string memory toChainIdStr,
        uint256 amount,
        string memory feeTokenStr,
        uint256 swapFee
    ) external returns (uint256) {
        require(
            IVotingEscrow(ve).ownerOf(tokenId) == msg.sender,
            "Theia StagingVault: Not owner of this veTHEIA"
        );

        string memory tokenStr = symbolToToken[tokenSymbol][toChainIdStr];
        require(
            bytes(tokenStr).length > 0,
            "Theia StagingVault: Liquidity token address does not exist on target chain"
        );
        address feeToken = stringToAddress(feeTokenStr);
        require(FeeManager(feeManager).getFeeTokenIndexMap(feeToken) > 0, 
            "Theia StagingVault: feeToken not exist"
        );

        nonceGlobal++;
        uint256 nonce = nonceGlobal; // one nonce per tx

        completed[nonce] = false;

        (uint256 destinationChainID, bool ok) = strToUint(toChainIdStr);
        require(ok, "Theia StagingVault:destinationChain invalid");

        string memory fromTargetStr = address(this).toHexString();

        if (destinationChainID == cID()) {
            // no cross-chain call
            stagingToLiquidityLocal(
                tokenStr,
                msg.sender.toHexString(),
                tokenId,
                amount,
                nonce
            );
        } else {
            uint256 feePaid = payFee(swapFee, feeToken);

            string
                memory funcCall = "stagingToLiquidity(string,string,string,uint256,uint256,uint256,string,uint256)";
            bytes memory callData = abi.encodeWithSignature(
                funcCall,
                fromTargetStr,
                tokenStr,
                msg.sender.toHexString(),
                tokenId,
                amount,
                nonce,
                feeTokenStr,
                feePaid
            );

            c3call(targetStr, toChainIdStr, callData);
        }

        return (nonce);
    }

    function payFee(uint256 fee, address feeToken) internal returns (uint256) {
        require(
            IERC20(feeToken).transferFrom(
                msg.sender,
                address(this),
                fee
            ),
            "FeeConfig: Fee payment failed"
        );
        return (fee);
    }

    function detachLiquidity(
        uint256 tokenId,
        string memory tokenSymbol,
        string memory targetStr,
        string memory toChainIdStr,
        uint256 amount,
        address feeToken,
        uint256 swapFee
    ) external returns (uint256) {
        require(
            IVotingEscrow(ve).ownerOf(tokenId) == msg.sender,
            "Theia StagingVault: Not owner of this veTHEIA"
        );
        require(
            block.timestamp >=
                liquidityRemovalTime[tokenId][tokenSymbol][toChainIdStr],
            "Theia StagingVault: Cannot remove liquidity yet"
        );
        require(
            liquidityByTokenId[tokenId][tokenSymbol][toChainIdStr] >= amount,
            "Theia StagingVault: the amount exceeds the liquidity of this token on this chain for TokenId"
        );
        require(FeeManager(feeManager).getFeeTokenIndexMap(feeToken) > 0, 
            "Theia StagingVault: feeToken not exist"
        );

        string memory feeTokenStr = feeToken.toHexString();

        string memory tokenStr = symbolToToken[tokenSymbol][toChainIdStr];

        nonceGlobal++;
        uint256 nonce = nonceGlobal; // one nonce per tx

        (uint256 destinationChainID, bool ok) = strToUint(toChainIdStr);
        require(ok, "Theia StagingVault:sourceChain invalid");

        string memory fromTargetStr = address(this).toHexString();

        if (destinationChainID == cID()) {
            // no cross-chain call
            liquidityToStagingLocal(
                tokenStr,
                msg.sender.toHexString(),
                tokenId,
                amount,
                nonce
            );
        } else {
            uint256 feePaid = payFee(swapFee, feeToken);

            string memory funcCall = "liquidityToStaging(string,string,string,string,uint256,uint256,uint256,string,uint256)";

            bytes memory callData = abi.encodeWithSignature(
                funcCall,
                fromTargetStr,
                tokenStr,
                msg.sender.toHexString(),
                tokenId,
                amount,
                nonce,
                feeTokenStr,
                feePaid
            );

            c3call(targetStr, toChainIdStr, callData);
        }

        return (nonce);
    }

    function reportLiquidityAttachment(
        string memory fromChainId,
        string memory lp,
        uint256 tokenId,
        string memory tokenStr,
        uint256 amount,
        uint256 nonce
    ) external onlyAuth {
        _reportLiquidityAttachmentLocal(
            fromChainId,
            lp,
            tokenId,
            tokenStr,
            amount,
            nonce
        );
    }

    function _reportLiquidityAttachmentLocal(
        string memory fromChainId,
        string memory lp,
        uint256 tokenId,
        string memory tokenStr,
        uint256 amount,
        uint256 nonce
    ) internal {
        tokenStr = _toLower(tokenStr);
        string memory tokenSymbol = tokenToSymbol[tokenStr][fromChainId];
        require(
            bytes(tokenSymbol).length > 0,
            "Theia StagingVault: tokenSymbol not found in _reportLiquidityAttachmentLocal"
        );

        liquidityAll[tokenId][tokenSymbol] += amount;
        liquidityByChain[tokenSymbol][fromChainId] += amount;
        liquidityByTokenId[tokenId][tokenSymbol][fromChainId] += amount;
        liquidityTotalAll[tokenSymbol] += amount;

        uint208 _liquidityOfAt = liquidityOfAt[tokenId][tokenSymbol][
            fromChainId
        ].upperLookupRecent(IVotingEscrow(ve).clock());
        liquidityOfAt[tokenId][tokenSymbol][fromChainId].push(
            IVotingEscrow(ve).clock(),
            _liquidityOfAt + uint208(amount)
        );

        liquidityRemovalTime[tokenId][tokenSymbol][fromChainId] =
            block.timestamp +
            liquidityDelay;

        completed[nonce] = true;
        emit ReportLiquidityAttachment(
            tokenId,
            lp,
            fromChainId,
            tokenStr,
            amount,
            nonce
        );
    }

    function reportLiquidityDetachment(
        string memory fromChainId,
        string memory lp,
        uint256 tokenId,
        string memory tokenStr,
        uint256 amount,
        uint256 nonce
    ) external onlyAuth {
        tokenStr = _toLower(tokenStr);
        _reportLiquidityDetachmentLocal(
            fromChainId,
            lp,
            tokenId,
            tokenStr,
            amount,
            nonce
        );
    }

    function _reportLiquidityDetachmentLocal(
        string memory fromChainId,
        string memory lp,
        uint256 tokenId,
        string memory tokenStr,
        uint256 amount,
        uint256 nonce
    ) internal {
        tokenStr = _toLower(tokenStr);
        string memory tokenSymbol = tokenToSymbol[tokenStr][fromChainId];
        require(
            bytes(tokenSymbol).length > 0,
            "Theia StagingVault: tokenSymbol not found in _reportLiquidityDetachmentLocal"
        );

        liquidityAll[tokenId][tokenSymbol] -= amount;
        liquidityByChain[tokenSymbol][fromChainId] -= amount;
        liquidityByTokenId[tokenId][tokenSymbol][fromChainId] -= amount;
        liquidityTotalAll[tokenSymbol] -= amount;

        uint208 _liquidityOfAt = liquidityOfAt[tokenId][tokenSymbol][
            fromChainId
        ].upperLookupRecent(IVotingEscrow(ve).clock());
        liquidityOfAt[tokenId][tokenSymbol][fromChainId].push(
            IVotingEscrow(ve).clock(),
            _liquidityOfAt - uint208(amount)
        );

        completed[nonce] = true;
        emit ReportLiquidityDetachment(
            tokenId,
            lp,
            fromChainId,
            tokenStr,
            amount,
            nonce
        );
    }

    function _c3Fallback(
        bytes4 _selector,
        bytes calldata _data,
        bytes calldata _reason
    ) internal override returns (bool) {
        string memory tokenStr;
        string memory lp;
        uint256 tokenId;
        uint256 amount;
        uint256 nonce;
        uint256 feePaid;

        if (_selector == FuncStagingToLiquidity) {
            (tokenStr, lp, tokenId, amount, nonce, feePaid) = abi.decode(
                _data,
                (string, string, uint256, uint256, uint256, uint256)
            );

            emit StagingToLiquidityFail(
                stringToAddress(lp),
                stringToAddress(tokenStr),
                tokenId,
                amount,
                nonce,
                feePaid,
                _reason
            );
        } else if (_selector == FuncLiquidityToStaging) {
            (tokenStr, tokenId, amount, nonce, feePaid) = abi.decode(
                _data,
                (string, uint256, uint256, uint256, uint256)
            );

            emit LiquidityToStagingFail(
                stringToAddress(tokenStr),
                tokenId,
                amount,
                nonce,
                feePaid,
                _reason
            );
        } else {
            emit LogFallback(_selector, _data, _reason);
        }

        return true;
    }

    function isRewardedToken(
        string memory tokenSymbol
    ) external view returns (bool) {
        return (rewarded[tokenSymbol]);
    }

    function getCompletedStatus(uint256 nonce) external view returns (bool) {
        return (completed[nonce]);
    }

    function tokenRewardRate(
        string memory tokenSymbol,
        string memory chainIdStr
    ) external view returns (uint256) {
        uint256 len = rewardedTokens[tokenSymbol].toChainIdsStr.length;

        for (uint256 i = 0; i < len; i++) {
            if (
                stringsEqual(
                    rewardedTokens[tokenSymbol].toChainIdsStr[i],
                    chainIdStr
                )
            ) {
                uint256 rateFactor = block.timestamp <
                    rateFactorEndTime[tokenSymbol][chainIdStr]
                    ? rewardedTokens[tokenSymbol].rateFactors[i] / 1000
                    : 1000;
                return (rewardedTokens[tokenSymbol].standardRewardRate *
                    rateFactor);
            }
        }
        revert("Theia StagingVault: Token rewards for this chainId not found");
    }

    function getRewardRate(
        string memory tokenSymbol,
        string memory chainIdStr,
        uint256 _timestamp
    ) external view returns (uint256) {
        uint256 rate = modifiedRewardRate[tokenSymbol][chainIdStr]
            .upperLookupRecent(SafeCast.toUint48(_timestamp));
        return (rate);
    }

    function getRewardRate(
        string memory tokenSymbol,
        string memory chainIdStr
    ) external view returns (uint256) {
        uint256 _timestamp = block.timestamp;
        uint256 rate = this.getRewardRate(tokenSymbol, chainIdStr, _timestamp);
        return (rate);
    }

    function getStandardRewardRate(
        string memory tokenSymbol,
        uint256 _timestamp
    ) external view returns (uint256) {
        uint256 rate = rewardRate[tokenSymbol].upperLookupRecent(
            SafeCast.toUint48(_timestamp)
        );
        return (rate);
    }

    function getStandardRewardRate(
        string memory tokenSymbol
    ) external view returns (uint256) {
        uint256 _timestamp = block.timestamp;
        uint256 rate = this.getStandardRewardRate(tokenSymbol, _timestamp);
        return (rate);
    }

    function getRewardToken(
        string memory tokenSymbol
    ) external view returns (RewardedToken memory) {
        return (rewardedTokens[tokenSymbol]);
    }

    function getRewardRateEnd(
        string memory tokenSymbol,
        string memory chainIdStr
    ) external view returns (uint256) {
        require(
            rewarded[tokenSymbol],
            "Theia StagingVault: Token was not listed for rewards"
        );
        return (rateFactorEndTime[tokenSymbol][chainIdStr]);
    }

    function getLiquidityRemovalTime(
        uint256 tokenId,
        string memory tokenSymbol,
        string memory chainIdStr
    ) external view returns (uint256) {
        return (liquidityRemovalTime[tokenId][tokenSymbol][chainIdStr]);
    }

    function getStakedTokenSymbols() external view returns (string[] memory) {
        return (stakedTokenSymbols);
    }

    function tokenSymbolExists(
        string memory tokenSymbol
    ) external view returns (bool, bool) {
        uint256 len = stakedTokenSymbols.length;
        for (uint256 i = 0; i < len; i++) {
            if (stringsEqual(tokenSymbol, stakedTokenSymbols[i])) {
                return (true, rewarded[tokenSymbol]);
            }
        }
        return (false, false);
    }

    function getTokenStakedAllChains(
        string memory tokenSymbol
    ) external view returns (uint256) {
        return (liquidityTotalAll[tokenSymbol]);
    }

    function getTokenStakedByChain(
        string memory tokenSymbol,
        string memory chainIdStr
    ) external view returns (uint256) {
        return (liquidityByChain[tokenSymbol][chainIdStr]);
    }

    function getTokenStakedByTokenId(
        uint256 tokenId,
        string memory tokenSymbol
    ) external view returns (uint256) {
        return (liquidityAll[tokenId][tokenSymbol]);
    }

    function getTokenStakedByTokenIdAndChain(
        uint256 tokenId,
        string memory tokenSymbol,
        string memory chainIdStr
    ) external view returns (uint256) {
        return (liquidityByTokenId[tokenId][tokenSymbol][chainIdStr]);
    }

    function getStakedAllChains(
        uint256 tokenId
    ) external view returns (string[] memory, uint256[] memory, bool) {
        uint256 len = stakedTokenSymbols.length;
        string[] memory symbols;
        uint256[] memory totals;
        bool liquidityRemains;

        for (uint256 i = 0; i < len; i++) {
            string memory tokenSymbol = stakedTokenSymbols[i];
            symbols[i] = tokenSymbol;
            totals[i] = liquidityAll[tokenId][tokenSymbol];
            if (totals[i] != 0) liquidityRemains = true;
        }

        return (symbols, totals, liquidityRemains);
    }

    function getLiquidityOfAt(
        uint256 _tokenId,
        string memory _tokenSymbol,
        string memory _chainIdStr,
        uint256 _timestamp
    ) external view returns (uint256) {
        return (
            liquidityOfAt[_tokenId][_tokenSymbol][_chainIdStr]
                .upperLookupRecent(SafeCast.toUint48(_timestamp))
        );
    }

    function getRewardRateOfAt(
        string memory _tokenSymbol,
        string memory _chainIdStr,
        uint256 _timestamp
    ) external view returns (uint256) {
        return (
            modifiedRewardRate[_tokenSymbol][_chainIdStr].upperLookupRecent(
                SafeCast.toUint48(_timestamp)
            )
        );
    }

    function getLiquidity(
        address token
    ) external view returns (uint256, uint256) {
        address underlying = ITheiaERC20(token).underlying();
        require(underlying != address(0));
        uint256 liquidity = IERC20(underlying).balanceOf(token);
        uint256 decimals = IERC20Extended(underlying).decimals();

        return (liquidity, decimals);
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

    function stringsEqual(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        bytes32 ka = keccak256(abi.encode(a));
        bytes32 kb = keccak256(abi.encode(b));
        return (ka == kb);
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
}
