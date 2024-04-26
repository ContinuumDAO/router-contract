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
        string calldata to,
        uint256 amount,
        string calldata toChainID,
        string calldata dapp,
        bytes calldata data
    ) external returns (bytes32 swapID);

    function isSwapCompleted(bytes32 swapID) external view returns (bool);
}

interface IC3ERC20 {
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

import "../protocol/C3CallerDapp.sol";
import "../protocol/IC3Caller.sol";
import "../routerV2/TheiaUtils.sol";

contract DemoRouter is C3CallerDapp {
    using SafeERC20 for IERC20;

    address public constant factory = address(0);
    address public immutable wNATIVE;

    // delay for timelock functions
    uint public constant DELAY = 2 days;

    mapping(address => bool) public isOperator;
    address[] public operators;

    address public swapIDKeeper;

    constructor(
        address _wNATIVE,
        address _mpc,
        address _swapIDKeeper,
        address _c3caller,
        uint256 _dappID
    ) C3CallerDapp(_c3caller, _dappID) {
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

    event LogChangeMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint indexed effectiveTime,
        uint256 chainID
    );
    event LogSwapIn(
        address indexed token,
        address indexed to,
        bytes32 indexed swapoutID,
        uint256 amount,
        uint256 fromChainID,
        uint256 toChainID,
        string sourceTx
    );
    event LogSwapOut(
        address indexed token,
        address indexed from,
        string to,
        uint256 amount,
        uint256 fromChainID,
        string toChainID,
        uint256 fee,
        bytes32 swapoutID
    );
    event LogAnySwapInAndExec(
        address indexed dapp,
        address indexed receiver,
        bytes32 swapID,
        address token,
        uint256 amount,
        uint256 fromChainID,
        string sourceTx,
        bool success,
        bytes result
    );

    event TestCall(uint256 x);

    event LogFallback(bytes4 selector, bytes data, bytes reason);

    modifier onlyMPC() {
        require(msg.sender == mpc(), "C3Router: MPC FORBIDDEN");
        _;
    }

    modifier onlyAuth() {
        require(isOperator[msg.sender], "C3ERC20: AUTH FORBIDDEN");
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

    function changeVault(
        address token,
        address newVault
    ) external onlyMPC returns (bool) {
        return IC3ERC20(token).changeVault(newVault);
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
            IC3ERC20(token).setFeeConfig(
                srcChainID,
                dstChainID,
                maxFee,
                minFee,
                feeRate,
                payFrom
            );
    }

    function setMinter(address token, address _auth) external onlyMPC {
        return IC3ERC20(token).setMinter(_auth);
    }

    function applyMinter(address token) external onlyMPC {
        return IC3ERC20(token).applyMinter();
    }

    function revokeMinter(address token, address _auth) external onlyMPC {
        return IC3ERC20(token).revokeMinter(_auth);
    }

    function checkSwapOut(address token, string calldata to) internal pure {
        require(token != address(0), "C3Router: from address(0)");
        require(bytes(to).length > 0, "C3Router: empty to address");
    }

    function checkC3Call(
        uint256 toChainID,
        string calldata to,
        string calldata dapp,
        bytes calldata data
    ) internal pure {
        require(toChainID > 0, "C3Call: empty toChainID");
        require(bytes(to).length > 0, "C3Call: empty to address");
        require(bytes(dapp).length > 0, "C3Call: empty dapp address");
        require(data.length > 0, "C3Call: empty c3 calldata");
    }

    function _buildAndCall(
        string calldata to,
        string calldata toChainID,
        bytes32 swapID,
        uint256 amount,
        address token,
        string calldata receiver
    ) internal {
        IC3CallerProxy(c3CallerProxy).c3call(
            dappID,
            to,
            toChainID,
            abi.encodeWithSignature(
                "swapInAuto(bytes32,address,address,uint256,uint256)",
                swapID,
                token,
                TheiaUtils.toAddress(receiver),
                amount,
                cID()
            )
        );
    }

    function _swapOut(
        address from,
        address token,
        uint256 amount,
        string calldata to,
        string calldata receiver,
        string calldata toChainID
    ) internal {
        bytes32 swapID = ISwapIDKeeper(swapIDKeeper).registerSwapout(
            token,
            from,
            to,
            amount,
            toChainID,
            "",
            bytes("")
        );

        _buildAndCall(to, toChainID, swapID, amount, token, receiver);

        emit LogSwapOut(token, from, to, amount, cID(), toChainID, 0, swapID);
    }

    function swapOut(
        address token,
        uint256 amount,
        string calldata to,
        string calldata receiver,
        string calldata toChainID
    ) external {
        _swapOut(msg.sender, token, amount, to, receiver, toChainID);
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID
    function _swapIn(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID
    ) internal returns (uint256) {
        (, , string memory _sourceTx, ) = context();
        emit LogSwapIn(
            token,
            to,
            swapID,
            amount,
            fromChainID,
            cID(),
            _sourceTx
        );
        return amount;
    }

    // swaps `amount` `token` in `fromChainID` to `to` on this chainID with `to` receiving `underlying` if possible
    function swapInAuto(
        bytes32 swapID,
        address token,
        address to,
        uint256 amount,
        uint256 fromChainID
    ) external onlyCaller {
        _swapIn(swapID, token, to, amount, fromChainID);
    }

    function _c3Fallback(
        bytes4 selector,
        bytes calldata data,
        bytes calldata reason
    ) internal override returns (bool) {
        emit LogFallback(selector, data, reason);
        return true;
    }

    function setX(uint256 x) external payable {
        IERC20(wNATIVE).transfer(msg.sender, x);
        emit TestCall(x);
    }
}
