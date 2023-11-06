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

import "./IC3Router.sol";
import "./ISwapIDKeeper.sol";

contract C3Router is IC3Router {
    using SafeERC20 for IERC20;

    struct Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
    }

    address public constant factory = address(0);
    address public immutable wNATIVE;

    // delay for timelock functions
    uint public constant DELAY = 2 days;

    mapping(address => bool) public isOperator;
    address[] public operators;

    address public swapIDKeeper;

    constructor(address _wNATIVE, address _mpc, address _swapIDKeeper) {
        _newMPC = _mpc;
        _newMPCEffectiveTime = block.timestamp;
        wNATIVE = _wNATIVE;
        swapIDKeeper = _swapIDKeeper;
        _addOperator(_mpc);
    }

    receive() external payable {}

    fallback() external payable {}

    address private _oldMPC;
    address private _newMPC;
    uint256 private _newMPCEffectiveTime;
    Context public override context;

    event LogChangeMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint indexed effectiveTime,
        uint256 chainID
    );
    event LogSwapOut(
        uint256 indexed dappID,
        address indexed token,
        address indexed from,
        string to,
        uint256 amount,
        uint256 fromChainID,
        string toChainID,
        bytes32 swapoutID,
        bytes data
    );
    event LogSwapIn(
        bytes32 indexed swapoutID,
        address indexed to,
        address indexed token,
        uint256 amount,
        address receiver,
        string fromChainID,
        string sourceTx
    );
    event LogAnySwapInAndExec(
        bytes32 indexed swapoutID,
        address indexed to,
        address indexed token,
        uint256 amount,
        address receiver,
        string fromChainID,
        string sourceTx,
        bytes data
    );

    modifier onlyMPC() {
        require(msg.sender == mpc(), "C3Router: MPC FORBIDDEN");
        _;
    }

    modifier onlyAuth() {
        require(isOperator[msg.sender], "C3Router: AUTH FORBIDDEN");
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

    function version() public pure returns (uint) {
        return 1;
    }

    function changeMPC(address newMPC) external onlyMPC returns (bool) {
        require(newMPC != address(0), "C3Router: address(0)");
        _oldMPC = mpc();
        _newMPC = newMPC;
        _newMPCEffectiveTime = block.timestamp + DELAY;
        emit LogChangeMPC(_oldMPC, _newMPC, _newMPCEffectiveTime, cID());
        return true;
    }

    function _addOperator(address op) internal {
        require(op != address(0), "C3Router: Operator is address(0)");
        require(!isOperator[op], "C3Router: Operator already exists");
        isOperator[op] = true;
        operators.push(op);
    }

    function addOperator(address _auth) external onlyMPC {
        _addOperator(_auth);
    }

    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }

    function revokeOperator(address _auth) external onlyMPC {
        require(isOperator[_auth], "C3Router: Operator not found");
        isOperator[_auth] = false;
        uint256 length = operators.length;
        for (uint256 i = 0; i < length; i++) {
            if (operators[i] == _auth) {
                operators[i] = operators[length - 1];
                operators.pop();
                return;
            }
        }
    }

    function changeSwapIDKeeper(address _swapIDKeeper) external onlyMPC {
        swapIDKeeper = _swapIDKeeper;
    }

    function checkSwapOut(
        uint256 dappID,
        address token,
        uint256 amount,
        string calldata toChainID,
        string calldata to,
        string calldata receiver
    ) internal pure {
        require(dappID > 0, "C3Router: empty dappID");
        require(token != address(0), "C3Router: token address(0)");
        require(amount > 0, "C3Router: empty amount");
        require(
            bytes(toChainID).length > 0,
            "C3Router: empty toChainID address"
        );
        require(bytes(to).length > 0, "C3Router: empty to address");
        require(bytes(receiver).length > 0, "C3Router: empty receiver address");
    }

    function checkSwapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        address receiver,
        string calldata fromChainID,
        string calldata sourceTx
    ) internal pure {
        require(swapID > 0, "C3Router: empty swapID");
        require(token != address(0), "C3Router: token address(0)");
        require(to != address(0), "C3Router: to address(0)");
        require(amount > 0, "C3Router: empty amount");
        require(receiver != address(0), "C3Router: receiver address(0)");
        require(bytes(fromChainID).length > 0, "C3Router: empty fromChainID");
        require(bytes(sourceTx).length > 0, "C3Router: empty sourceTx");
    }

    // need approve to c3router first
    function _transferFromToken(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        uint256 old_balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 new_balance = IERC20(token).balanceOf(address(this));
        require(
            new_balance >= old_balance && new_balance <= old_balance + amount
        );
        return new_balance - old_balance;
    }

    function _transferFromNative() internal returns (uint256) {
        require(wNATIVE != address(0), "C3Router: zero wNATIVE");
        uint256 old_balance = IERC20(wNATIVE).balanceOf(address(this));
        IwNATIVE(wNATIVE).deposit{value: msg.value}();
        uint256 new_balance = IERC20(wNATIVE).balanceOf(address(this));
        require(
            new_balance >= old_balance && new_balance <= old_balance + msg.value
        );
        return new_balance - old_balance;
    }

    function _swapOut(
        uint256 dappID,
        address from,
        address token,
        uint256 amount,
        string calldata toChainID,
        string calldata to,
        string calldata receiver,
        bytes memory data
    ) internal returns (bytes32) {
        checkSwapOut(dappID, token, amount, toChainID, to, receiver);
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
            dappID,
            token,
            from,
            to,
            amount,
            toChainID,
            data
        );
        uint256 amountOut = _transferFromToken(token, amount);
        emit LogSwapOut(
            dappID,
            token,
            from,
            to,
            amountOut,
            cID(),
            toChainID,
            swapID,
            data
        );
        return swapID;
    }

    function multiSwapOut(
        uint256 dappId,
        address[] calldata tokens,
        string[] calldata to,
        uint256[] calldata amounts,
        string[] calldata toChainIDs,
        string[] calldata receivers
    ) external {
        for (uint i = 0; i < tokens.length; i++) {
            _swapOut(
                dappId,
                msg.sender,
                tokens[i],
                amounts[i],
                toChainIDs[i],
                to[i],
                receivers[i],
                ""
            );
        }
    }

    function swapOut(
        uint256 dappID,
        address token,
        uint256 amount,
        string calldata toChainID,
        string calldata to,
        string calldata receiver
    ) external returns (bytes32) {
        return
            _swapOut(
                dappID,
                msg.sender,
                token,
                amount,
                toChainID,
                to,
                receiver,
                ""
            );
    }

    function swapOutNative(
        uint256 dappID,
        string calldata toChainID,
        string calldata to,
        string calldata receiver
    ) external payable returns (bytes32) {
        checkSwapOut(dappID, wNATIVE, msg.value, toChainID, to, receiver);

        uint256 recvAmount = _transferFromNative();
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
            dappID,
            address(0),
            msg.sender,
            to,
            recvAmount,
            toChainID,
            ""
        );
        emit LogSwapOut(
            dappID,
            address(0),
            msg.sender,
            to,
            recvAmount,
            cID(),
            toChainID,
            swapID,
            ""
        );
        return swapID;
    }

    function swapOutAndCall(
        uint256 dappID,
        address token,
        uint256 amount,
        string calldata toChainID,
        string calldata to,
        string calldata receiver,
        bytes calldata data
    ) external returns (bytes32) {
        require(data.length > 0, "C3Router: empty call data");
        return
            _swapOut(
                dappID,
                msg.sender,
                token,
                amount,
                toChainID,
                to,
                receiver,
                data
            );
    }

    function swapOutNativeAndCall(
        uint256 dappID,
        string calldata toChainID,
        string calldata to,
        string calldata receiver,
        bytes calldata data
    ) external payable returns (bytes32) {
        checkSwapOut(dappID, wNATIVE, msg.value, toChainID, to, receiver);
        require(data.length > 0, "C3Router: empty call data");

        uint256 recvAmount = _transferFromNative();
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
            dappID,
            address(0),
            msg.sender,
            to,
            recvAmount,
            toChainID,
            data
        );
        emit LogSwapOut(
            dappID,
            address(0),
            msg.sender,
            to,
            recvAmount,
            cID(),
            toChainID,
            swapID,
            data
        );
        return swapID;
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID
    function _swapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        address receiver,
        string calldata fromChainID,
        string calldata sourceTx
    ) internal {
        checkSwapIn(swapID, token, to, amount, receiver, fromChainID, sourceTx);
        ISwapIDKeeper(swapIDKeeper).registerSwapin(swapID);

        context = Context({
            swapID: swapID,
            fromChainID: fromChainID,
            sourceTx: sourceTx
        });

        bool success;
        string memory result;
        try
            IC3RouterExecutor(to).execute(swapID, token, receiver, amount)
        returns (bool succ, bytes memory res) {
            (success, result) = (succ, string(res));
        } catch Error(string memory reason) {
            result = reason;
        } catch (bytes memory reason) {
            result = string(reason);
        }

        require(success, string.concat("C3Router: ", result));

        context = Context({swapID: "", fromChainID: "", sourceTx: ""});

        emit LogSwapIn(
            swapID,
            to,
            token,
            amount,
            receiver,
            fromChainID,
            sourceTx
        );
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID
    function swapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        address receiver,
        string calldata fromChainID,
        string calldata sourceTx
    ) external onlyAuth {
        _swapIn(swapID, token, to, amount, receiver, fromChainID, sourceTx);
    }

    function swapInAndExec(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        address receiver,
        string calldata fromChainID,
        string calldata sourceTx,
        bytes calldata data
    ) external onlyAuth {
        checkSwapIn(swapID, token, to, amount, receiver, fromChainID, sourceTx);
        require(data.length > 0, "C3Call: empty c3 calldata");
        ISwapIDKeeper(swapIDKeeper).registerSwapin(swapID);

        context = Context({
            swapID: swapID,
            fromChainID: fromChainID,
            sourceTx: sourceTx
        });

        bool success;
        string memory result;
        try
            IC3RouterExecutor(to).executeAndCall(
                swapID,
                token,
                receiver,
                amount,
                data
            )
        returns (bool succ, bytes memory res) {
            (success, result) = (succ, string(res));
        } catch Error(string memory reason) {
            result = reason;
        } catch (bytes memory reason) {
            result = string(reason);
        }
        require(success, string.concat("C3Router: ", result));

        context = Context({swapID: "", fromChainID: "", sourceTx: ""});

        emit LogAnySwapInAndExec(
            swapID,
            to,
            token,
            amount,
            receiver,
            fromChainID,
            sourceTx,
            data
        );
    }

    function swapIn(
        bytes32[] calldata swapIDs,
        address[] calldata tokens,
        address[] calldata to,
        uint256[] calldata amounts,
        address[] calldata receivers,
        string[] calldata fromChainIDs,
        string[] calldata sourceTxs
    ) external onlyAuth {
        for (uint i = 0; i < tokens.length; i++) {
            _swapIn(
                swapIDs[i],
                tokens[i],
                to[i],
                amounts[i],
                receivers[i],
                fromChainIDs[i],
                sourceTxs[i]
            );
        }
    }
}
