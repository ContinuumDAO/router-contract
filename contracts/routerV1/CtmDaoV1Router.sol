// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

// helper methods for interacting with ERC20 tokens and sending NATIVE that do not consistently return true/false
library TransferHelper {
    function safeTransferNative(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: NATIVE_TRANSFER_FAILED");
    }
}

interface IwNATIVE {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface ISwapIDKeeper {
    function registerSwapin(bytes32 swapID) external;

    function registerSwapout(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 toChainID
    ) external returns (bytes32 swapID);

    function registerNonEvmSwapout(
        address token,
        address from,
        string calldata to,
        uint256 amount,
        uint256 toChainID
    ) external returns (bytes32 swapID);

    function isSwapCompleted(bytes32 swapID) external view returns (bool);
}

interface ICtmDaoV1ERC20 {
    function mint(address to, uint256 amount) external returns (bool);

    function burn(address from, uint256 amount) external returns (bool);

    function setMinter(address _auth) external;

    function applyMinter() external;

    function revokeMinter(address _auth) external;

    function changeVault(address newVault) external returns (bool);

    function depositVault(
        uint256 amount,
        address to
    ) external returns (uint256);

    function withdrawVault(
        address from,
        uint256 amount,
        address to
    ) external returns (uint256);

    function underlying() external view returns (address);

    function deposit(uint256 amount, address to) external returns (uint256);

    function withdraw(uint256 amount, address to) external returns (uint256);

    function setFeeConfig(
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom
    ) external returns (bool);

    function getFeeConfig(
        uint256 fromChainID,
        uint256 toChainID
    ) external view returns (uint256, uint256, uint256);
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

contract CtmDaoV1Router {
    using SafeERC20 for IERC20;

    address public constant factory = address(0);
    address public immutable wNATIVE;

    // delay for timelock functions
    uint public constant DELAY = 2 days;

    mapping(address => bool) public isOperator;

    address public swapIDKeeper;

    constructor(address _wNATIVE, address _mpc, address _swapIDKeeper) {
        _newMPC = _mpc;
        _newMPCEffectiveTime = block.timestamp;
        wNATIVE = _wNATIVE;
        isOperator[_mpc] = true;
        swapIDKeeper = _swapIDKeeper;
    }

    receive() external payable {
        assert(msg.sender == wNATIVE); // only accept Native via fallback from the wNative contract
    }

    address private _oldMPC;
    address private _newMPC;
    uint256 private _newMPCEffectiveTime;

    event LogChangeMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint indexed effectiveTime,
        uint256 chainID
    );
    event LogAnySwapIn(
        address indexed token,
        address indexed to,
        bytes32 indexed swapoutID,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        string sourceTx
    );
    event LogAnySwapOut(
        address indexed token,
        address indexed from,
        address to,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 fee,
        bytes32 swapoutID
    );
    event LogAnySwapOutNonEvm(
        address indexed token,
        address indexed from,
        string to,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 fee,
        bytes32 swapoutID
    );

    modifier onlyMPC() {
        require(msg.sender == mpc(), "CtmDaoV1Router: MPC FORBIDDEN");
        _;
    }

    modifier onlyAuth() {
        require(isOperator[msg.sender], "CtmDaoV1ERC20: AUTH FORBIDDEN");
        _;
    }

    function mpc() public view returns (address) {
        if (block.timestamp >= _newMPCEffectiveTime) {
            return _newMPC;
        }
        return _oldMPC;
    }

    function cID() public view returns (uint) {
        return block.chainid;
    }

    function changeMPC(address newMPC) external onlyMPC returns (bool) {
        require(newMPC != address(0), "CtmDaoV1Router: address(0)");
        _oldMPC = mpc();
        _newMPC = newMPC;
        _newMPCEffectiveTime = block.timestamp + DELAY;
        emit LogChangeMPC(_oldMPC, _newMPC, _newMPCEffectiveTime, cID());
        return true;
    }

    function addOperator(address _auth) external onlyMPC {
        require(_auth != address(0), "CtmDaoV1Router: address(0)");
        isOperator[_auth] = true;
    }

    function revokeOperator(address _auth) external onlyMPC {
        isOperator[_auth] = false;
    }

    function changeVault(
        address token,
        address newVault
    ) external onlyMPC returns (bool) {
        return ICtmDaoV1ERC20(token).changeVault(newVault);
    }

    function changeSwapIDKeeper(address _swapIDKeeper) external onlyMPC {
        swapIDKeeper = _swapIDKeeper;
    }

    function setTokenFeeConfig(
        address token,
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom
    ) external onlyMPC returns (bool) {
        return
            ICtmDaoV1ERC20(token).setFeeConfig(
                srcChainID,
                dstChainID,
                maxFee,
                minFee,
                feeRate,
                payFrom
            );
    }

    function setMinter(address token, address _auth) external onlyMPC {
        return ICtmDaoV1ERC20(token).setMinter(_auth);
    }

    function applyMinter(address token) external onlyMPC {
        return ICtmDaoV1ERC20(token).applyMinter();
    }

    function revokeMinter(address token, address _auth) external onlyMPC {
        return ICtmDaoV1ERC20(token).revokeMinter(_auth);
    }

    function _anySwapOut(
        address from,
        address token,
        address to,
        uint256 amount,
        uint256 toChainID
    ) internal {
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
            token,
            from,
            to,
            amount,
            toChainID
        );
        ICtmDaoV1ERC20(token).burn(from, amount);
        uint256 swapFee = calcSwapFee(0, toChainID, token, amount);
        if (swapFee > 0) {
            ICtmDaoV1ERC20(token).mint(address(this), swapFee);
        }

        emit LogAnySwapOut(
            token,
            from,
            to,
            amount,
            cID(),
            toChainID,
            swapFee,
            swapID
        );
    }

    // Swaps `amount` `token` from this chain to `toChainID` chain with recipient `to`
    function anySwapOut(
        address token,
        address to,
        uint256 amount,
        uint256 toChainID
    ) external {
        _anySwapOut(msg.sender, token, to, amount, toChainID);
    }

    // need approve to router first
    function _anySwapOutUnderlying(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        address _underlying = ICtmDaoV1ERC20(token).underlying();
        require(_underlying != address(0), "CtmDaoV1Router: no underlying");
        uint256 old_balance = IERC20(_underlying).balanceOf(token);
        IERC20(_underlying).safeTransferFrom(msg.sender, token, amount);
        uint256 new_balance = IERC20(_underlying).balanceOf(token);
        require(
            new_balance >= old_balance && new_balance <= old_balance + amount
        );
        return new_balance - old_balance;
    }

    // Swaps `amount` `token` from this chain to `toChainID` chain with recipient `to` by minting with `underlying`
    function anySwapOutUnderlying(
        address token,
        address to,
        uint256 amount,
        uint256 toChainID
    ) external {
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
            token,
            msg.sender,
            to,
            amount,
            toChainID
        );
        uint256 recvAmount = _anySwapOutUnderlying(token, amount);
        uint256 swapFee = calcSwapFee(0, toChainID, token, amount);
        if (swapFee > 0) {
            ICtmDaoV1ERC20(token).mint(address(this), swapFee);
        }
        emit LogAnySwapOut(
            token,
            msg.sender,
            to,
            recvAmount,
            cID(),
            toChainID,
            swapFee,
            swapID
        );
    }

    function _anySwapOutNative(address token) internal returns (uint256) {
        require(wNATIVE != address(0), "CtmDaoV1Router: zero wNATIVE");
        require(
            ICtmDaoV1ERC20(token).underlying() == wNATIVE,
            "CtmDaoV1Router: underlying is not wNATIVE"
        );
        uint256 old_balance = IERC20(wNATIVE).balanceOf(token);
        IwNATIVE(wNATIVE).deposit{value: msg.value}();
        IERC20(wNATIVE).safeTransfer(token, msg.value);
        uint256 new_balance = IERC20(wNATIVE).balanceOf(token);
        require(
            new_balance >= old_balance && new_balance <= old_balance + msg.value
        );
        return new_balance - old_balance;
    }

    function anySwapOutNative(
        address token,
        address to,
        uint256 toChainID
    ) external payable {
        uint256 recvAmount = _anySwapOutNative(token);
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
            token,
            msg.sender,
            to,
            recvAmount,
            toChainID
        );
        uint256 swapFee = calcSwapFee(0, toChainID, token, recvAmount);
        if (swapFee > 0) {
            ICtmDaoV1ERC20(token).mint(address(this), swapFee);
        }
        emit LogAnySwapOut(
            token,
            msg.sender,
            to,
            recvAmount,
            cID(),
            toChainID,
            swapFee,
            swapID
        );
    }

    function anySwapOut(
        address[] calldata tokens,
        address[] calldata to,
        uint256[] calldata amounts,
        uint256[] calldata toChainIDs
    ) external {
        for (uint i = 0; i < tokens.length; i++) {
            _anySwapOut(
                msg.sender,
                tokens[i],
                to[i],
                amounts[i],
                toChainIDs[i]
            );
        }
    }

    function anySwapOut(
        address token,
        string memory to,
        uint256 amount,
        uint256 toChainID
    ) external {
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerNonEvmSwapout(
            token,
            msg.sender,
            to,
            amount,
            toChainID
        );
        ICtmDaoV1ERC20(token).burn(msg.sender, amount);
        uint256 swapFee = calcSwapFee(0, toChainID, token, amount);
        if (swapFee > 0) {
            ICtmDaoV1ERC20(token).mint(address(this), swapFee);
        }
        emit LogAnySwapOutNonEvm(
            token,
            msg.sender,
            to,
            amount,
            cID(),
            toChainID,
            swapFee,
            swapID
        );
    }

    function anySwapOutUnderlying(
        address token,
        string memory to,
        uint256 amount,
        uint256 toChainID
    ) external {
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerNonEvmSwapout(
            token,
            msg.sender,
            to,
            amount,
            toChainID
        );
        uint256 recvAmount = _anySwapOutUnderlying(token, amount);
        uint256 swapFee = calcSwapFee(0, toChainID, token, recvAmount);
        if (swapFee > 0) {
            ICtmDaoV1ERC20(token).mint(address(this), swapFee);
        }
        emit LogAnySwapOutNonEvm(
            token,
            msg.sender,
            to,
            recvAmount,
            cID(),
            toChainID,
            swapFee,
            swapID
        );
    }

    function anySwapOutNative(
        address token,
        string memory to,
        uint256 toChainID
    ) external payable {
        uint256 recvAmount = _anySwapOutNative(token);
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerNonEvmSwapout(
            token,
            msg.sender,
            to,
            recvAmount,
            toChainID
        );
        uint256 swapFee = calcSwapFee(0, toChainID, token, recvAmount);
        if (swapFee > 0) {
            ICtmDaoV1ERC20(token).mint(address(this), swapFee);
        }
        emit LogAnySwapOutNonEvm(
            token,
            msg.sender,
            to,
            recvAmount,
            cID(),
            toChainID,
            swapFee,
            swapID
        );
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID
    function _anySwapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string calldata sourceTx
    ) internal returns (uint256) {
        ISwapIDKeeper(swapIDKeeper).registerSwapin(swapID);
        uint256 swapFee = calcSwapFee(fromChainID, 0, token, amount);
        if (swapFee > 0) {
            ICtmDaoV1ERC20(token).mint(address(this), swapFee);
        }
        ICtmDaoV1ERC20(token).mint(to, amount - swapFee);
        emit LogAnySwapIn(
            token,
            to,
            swapID,
            amount - swapFee,
            fromChainID,
            cID(),
            sourceTx
        );
        return amount - swapFee;
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID
    // triggered by `anySwapOut`
    function anySwapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string calldata sourceTx
    ) external onlyAuth {
        _anySwapIn(swapID, token, to, amount, fromChainID, sourceTx);
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID with `to` receiving `underlying`
    function anySwapInUnderlying(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string calldata sourceTx
    ) external onlyAuth {
        uint256 recvAmount = _anySwapIn(
            swapID,
            token,
            to,
            amount,
            fromChainID,
            sourceTx
        );
        ICtmDaoV1ERC20(token).withdrawVault(to, recvAmount, to);
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID with `to` receiving `underlying` if possible
    function anySwapInAuto(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID,
        string calldata sourceTx
    ) external onlyAuth {
        uint256 recvAmount = _anySwapIn(
            swapID,
            token,
            to,
            amount,
            fromChainID,
            sourceTx
        );
        ICtmDaoV1ERC20 _anyToken = ICtmDaoV1ERC20(token);
        address _underlying = _anyToken.underlying();
        if (
            _underlying != address(0) &&
            IERC20(_underlying).balanceOf(token) >= recvAmount
        ) {
            if (_underlying == wNATIVE) {
                _anyToken.withdrawVault(to, recvAmount, address(this));
                IwNATIVE(wNATIVE).withdraw(recvAmount);
                TransferHelper.safeTransferNative(to, recvAmount);
            } else {
                _anyToken.withdrawVault(to, recvAmount, to);
            }
        }
    }

    function depositNative(
        address token,
        address to
    ) external payable returns (uint256) {
        require(wNATIVE != address(0), "CtmDaoV1Router: zero wNATIVE");
        require(
            ICtmDaoV1ERC20(token).underlying() == wNATIVE,
            "CtmDaoV1Router: underlying is not wNATIVE"
        );
        IwNATIVE(wNATIVE).deposit{value: msg.value}();
        assert(IwNATIVE(wNATIVE).transfer(token, msg.value));
        ICtmDaoV1ERC20(token).depositVault(msg.value, to);
        return msg.value;
    }

    function withdrawNative(
        address token,
        uint256 amount,
        address to
    ) external returns (uint256) {
        require(wNATIVE != address(0), "CtmDaoV1Router: zero wNATIVE");
        require(
            ICtmDaoV1ERC20(token).underlying() == wNATIVE,
            "CtmDaoV1Router: underlying is not wNATIVE"
        );

        uint256 old_balance = IERC20(wNATIVE).balanceOf(address(this));
        ICtmDaoV1ERC20(token).withdrawVault(msg.sender, amount, address(this));
        uint256 new_balance = IERC20(wNATIVE).balanceOf(address(this));
        assert(new_balance == old_balance + amount);

        IwNATIVE(wNATIVE).withdraw(amount);
        TransferHelper.safeTransferNative(to, amount);
        return amount;
    }

    //  extracts mpc fee from bridge fees
    function anySwapFeeTo(address[] calldata tokens) external onlyMPC {
        address _mpc = mpc();
        for (uint index = 0; index < tokens.length; index++) {
            address _token = tokens[index];
            uint256 amount = IERC20(_token).balanceOf(address(this));
            if (amount > 0) {
                ICtmDaoV1ERC20(_token).withdrawVault(
                    address(this),
                    amount,
                    _mpc
                );
            }
        }
    }

    function anySwapIn(
        bytes32[] calldata swapIDs,
        address[] calldata tokens,
        address[] calldata to,
        uint256[] calldata amounts,
        uint256[] calldata fromChainIDs,
        string[] calldata sourceTxs
    ) external onlyAuth {
        for (uint i = 0; i < tokens.length; i++) {
            _anySwapIn(
                swapIDs[i],
                tokens[i],
                to[i],
                amounts[i],
                fromChainIDs[i],
                sourceTxs[i]
            );
        }
    }

    // TODO: how to ensure that the fee config are both setted in fromChain and toChain correctly
    function calcSwapFee(
        uint256 fromChainID,
        uint256 toChainID,
        address token,
        uint256 amount
    ) public view returns (uint256) {
        (
            uint256 maximumSwapFee,
            uint256 minimumSwapFee,
            uint256 swapFeeRatePerMillion
        ) = ICtmDaoV1ERC20(token).getFeeConfig(fromChainID, toChainID);
        if (swapFeeRatePerMillion == 0) return 0;
        if (maximumSwapFee > 0 && maximumSwapFee == minimumSwapFee)
            return maximumSwapFee;
        uint256 _fee = (amount * swapFeeRatePerMillion) / 1000000;
        require(_fee < amount, "CtmDaoV1Router: Invalid FeeConfig");
        _fee = maximumSwapFee < _fee ? maximumSwapFee : _fee;
        _fee = minimumSwapFee > _fee ? minimumSwapFee : _fee;
        return _fee;
    }
}
